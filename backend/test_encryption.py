"""Encryption/migration tests run exclusively against a separate *_test DB."""
import copy
import os
from pathlib import Path
import secrets
import tempfile
import unittest
from unittest.mock import patch

from psycopg.types.json import Jsonb
from app import app, connect, load, migrate
from encryption import (EncryptionError, Vault, initialize_key, key_path, read_master,
                        seal, unseal, vault)
import test_api as fixtures
from test_api import HEADERS, PASSWORD


class EnvelopeTests(unittest.TestCase):
    def test_nonce_randomization_and_authentication(self):
        key, aad = secrets.token_bytes(32), b'test-only-user-and-path'
        first, second = seal(key, b'financial data', aad), seal(key, b'financial data', aad)
        self.assertNotEqual(first, second)
        self.assertEqual(unseal(key, first, aad), b'financial data')
        for candidate, candidate_aad, candidate_key in (
                (first, b'other-user', key), (first, aad, secrets.token_bytes(32)),
                (first[:-1] + bytes([first[-1] ^ 1]), aad, key), (first[:20], aad, key)):
            with self.assertRaises(EncryptionError):
                unseal(candidate_key, candidate, candidate_aad)

    def test_key_initializer_preserves_existing_key_and_refuses_missing_or_invalid(self):
        with tempfile.TemporaryDirectory() as folder, patch.dict(os.environ, {'MYSOLD_KEY_FILE': folder + '/keys/master.key'}):
            with self.assertRaises(EncryptionError):
                read_master()
            initialize_key()
            original = read_master()
            initialize_key()
            self.assertEqual(read_master(), original)
            key_path().write_bytes(b'incomplete')
            with self.assertRaises(EncryptionError):
                initialize_key()
            self.assertEqual(key_path().read_bytes(), b'incomplete')


class EncryptionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixtures.ApiTests.setUpClass()

    setUp = fixtures.ApiTests.setUp
    register = fixtures.ApiTests.register
    path = fixtures.ApiTests.path
    operation = fixtures.ApiTests.operation
    commit = fixtures.ApiTests.commit
    get = fixtures.ApiTests.get
    seed = fixtures.ApiTests.seed

    def record(self, path='user', uid=None):
        with connect() as db:
            return db.execute('SELECT path,data,sealed_data FROM documents WHERE user_id=%s AND path=%s', (uid or self.uid, path)).fetchone()

    def test_distinct_user_keys_encrypted_profile_and_randomized_writes(self):
        with connect() as db:
            first, second = vault(db).user_key(self.uid), vault(db).user_key(self.other_uid)
            wrapped = db.execute('SELECT wrapped_key FROM user_data_keys WHERE user_id=%s', (self.uid,)).fetchone()['wrapped_key']
        self.assertNotEqual(first, second)
        self.assertNotIn(first, bytes(wrapped))
        row = self.record()
        self.assertNotIn('firstName', row['data'])
        self.assertNotIn('pin', row['data'])
        self.assertNotIn(b'Test', bytes(row['sealed_data']))
        self.assertEqual(self.get('user')['firstName'], 'Test')
        self.commit([self.operation('user', {'firstName': 'Test'}, 'update')])
        self.assertNotEqual(row['sealed_data'], self.record()['sealed_data'])

    def test_amounts_and_names_private_but_filters_order_and_cursor_still_work(self):
        self.seed()
        row = self.record('accounts/cash')
        self.assertNotIn('balance', row['data'])
        self.assertNotIn('name', row['data'])
        response = self.client.post('/api/documents/query', headers=HEADERS, json={
            'path': self.path('accounts'), 'filters': [{'field': 'name', 'op': 'eq', 'value': 'Cash'}], 'order': 'name'})
        self.assertEqual(response.status_code, 200, response.json)
        self.assertEqual(response.json['documents'][0]['data']['balance'], 100)
        response = self.client.post('/api/documents/query', headers=HEADERS, json={'path': self.path('accounts'), 'order': 'name', 'limit': 1})
        self.assertEqual(len(response.json['documents']), 1)
        self.assertIsNone(response.json['cursor'])
        response = self.client.post('/api/documents/query', headers=HEADERS, json={
            'path': self.path('accounts'), 'filters': [{'field': 'balance', 'op': 'gte', 'value': 100}], 'order': 'balance'})
        self.assertEqual([r['data']['balance'] for r in response.json['documents']], [100])

    def test_swapped_ciphertext_and_modified_index_fail_closed(self):
        self.seed()
        row = self.record('accounts/cash')
        with connect() as db:
            db.execute("UPDATE documents SET sealed_data=%s WHERE user_id=%s AND path='accounts/holding'", (row['sealed_data'], self.uid))
        response = self.client.post('/api/documents/get', headers=HEADERS, json={'path': self.path('accounts/holding')})
        self.assertEqual(response.status_code, 500)
        self.assertNotIn('Cash', str(response.json))
        with connect() as db:
            db.execute("UPDATE documents SET data=%s WHERE user_id=%s AND path='accounts/cash'", (Jsonb({'type': 'forged'}), self.uid))
        self.assertEqual(self.client.post('/api/documents/get', headers=HEADERS, json={'path': self.path('accounts/cash')}).status_code, 500)

    def test_legacy_migration_preserves_documents_mfa_and_is_idempotent(self):
        legacy = {'name': 'Ancien compte privé', 'balance': 123.45}
        with connect() as db:
            db.execute("INSERT INTO documents(user_id,path,collection,data) VALUES (%s,'accounts/legacy','accounts',%s)", (self.uid, Jsonb(legacy)))
            db.execute('INSERT INTO mfa(user_id,secret,pending_secret) VALUES (%s,%s,%s)', (self.uid, 'JBSWY3DPEHPK3PXP', 'KRSXG5DSNFXGOIDB'))
        migrate()
        self.assertEqual(self.get('accounts/legacy'), legacy)
        before = self.record('accounts/legacy')
        self.assertEqual(before['data'], {})
        with connect() as db:
            row = db.execute('SELECT secret,pending_secret FROM mfa WHERE user_id=%s', (self.uid,)).fetchone()
            self.assertTrue(all(value.startswith('aesgcm:v1:') for value in row.values()))
            self.assertEqual(vault(db).mfa_open(self.uid, row['secret']), 'JBSWY3DPEHPK3PXP')
        migrate()
        self.assertEqual(before, self.record('accounts/legacy'))

    def test_wrong_key_refuses_startup_without_changing_data(self):
        before = copy.deepcopy(self.record())
        with tempfile.TemporaryDirectory() as folder:
            wrong = Path(folder) / 'master.key'
            wrong.write_bytes(secrets.token_bytes(32))
            wrong.chmod(0o600)
            with patch.dict(os.environ, {'MYSOLD_KEY_FILE': str(wrong)}):
                with self.assertRaises(EncryptionError):
                    migrate()
        self.assertEqual(before, self.record())
        self.assertEqual(self.get('user')['firstName'], 'Test')

    def test_interrupted_migration_resumes_after_the_last_committed_batch(self):
        with connect() as db:
            db.execute("INSERT INTO documents(user_id,path,collection,data) SELECT %s,'accounts/resume-' || n,'accounts',%s FROM generate_series(1,201) AS n",
                       (self.uid, Jsonb({'name': 'Legacy batch fixture', 'balance': 1.25})))
        original, calls = Vault.encode, 0
        def interrupted(store, *args):
            nonlocal calls
            calls += 1
            if calls == 201:
                raise RuntimeError('Simulated interruption in a test fixture')
            return original(store, *args)
        with patch.object(Vault, 'encode', interrupted), self.assertRaises(RuntimeError):
            migrate()
        with connect() as db:
            count = db.execute("SELECT count(*) AS n FROM documents WHERE user_id=%s AND path LIKE 'accounts/resume-%%' AND sealed_data IS NOT NULL", (self.uid,)).fetchone()['n']
        self.assertEqual(count, 200)
        migrate()
        self.assertEqual(self.get('accounts/resume-201')['balance'], 1.25)

    def test_retired_annual_json_is_preserved_encrypted_without_restarting_tracking(self):
        with connect() as db:
            db.execute('CREATE TABLE IF NOT EXISTS annual_snapshots (user_id text REFERENCES users(id) ON DELETE CASCADE, year integer, data jsonb, PRIMARY KEY(user_id,year))')
            db.execute('INSERT INTO annual_snapshots(user_id,year,data) VALUES (%s,2026,%s)',
                       (self.uid, Jsonb({'privateBalance': 1234.56})))
        migrate()
        with connect() as db:
            row = db.execute('SELECT data FROM annual_snapshots WHERE user_id=%s', (self.uid,)).fetchone()
        self.assertIn('_mysold_encrypted', row['data'])
        self.assertNotIn('1234.56', str(row['data']))
        migrate()
        with connect() as db:
            self.assertEqual(row, db.execute('SELECT data FROM annual_snapshots WHERE user_id=%s', (self.uid,)).fetchone())

    def test_https_origin_forces_secure_session_cookie_even_if_env_false(self):
        with patch.dict(os.environ, {'APP_ORIGIN': 'https://secure.example.test', 'COOKIE_SECURE': 'false'}):
            result = app.test_client().post('/api/auth/login', headers={**HEADERS, 'Origin': 'https://secure.example.test'},
                                            json={'email': 'first@example.test', 'password': PASSWORD})
        self.assertEqual(result.status_code, 200, result.json)
        self.assertIn('Secure;', result.headers['Set-Cookie'])
        self.assertIn('lastConnection', self.get('user'))


if __name__ == '__main__':
    unittest.main()

import os
import time
import unittest
from concurrent.futures import ThreadPoolExecutor
from unittest.mock import patch
from app import app, connect, migrate
import totp

HEADERS = {'X-MySold-Request': '1', 'Origin': 'http://localhost:28085'}
PASSWORD = 'Test-password-123!'


class MfaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not os.environ.get('POSTGRES_DB', '').endswith('_test'):
            raise RuntimeError('An isolated _test database is required.')
        os.environ['COOKIE_SECURE'] = 'false'
        os.environ['APP_ORIGIN'] = HEADERS['Origin']
        migrate()

    def setUp(self):
        with connect() as db:
            db.execute('DELETE FROM users')
            db.execute('DELETE FROM rate_limits')
        self.client = app.test_client()
        response = self.post('register', {'email': 'mfa@example.test', 'password': PASSWORD, 'profile': {'pin': 'a' * 64}})
        self.assertEqual(response.status_code, 200)
        self.uid = response.json['user']['uid']
        self.counter = int(time.time()) // 30

    def post(self, action, data, client=None):
        return (client or self.client).post('/api/auth/' + action, json=data, headers=HEADERS)

    def enroll(self):
        setup = self.post('mfa/setup', {'password': PASSWORD})
        self.assertEqual(setup.status_code, 200, setup.json)
        self.secret = setup.json['secret']
        with patch('totp.time.time', return_value=self.counter * 30):
            enabled = self.post('mfa/enable', {'password': PASSWORD, 'code': totp.code_at(self.secret, self.counter)})
        self.assertEqual(enabled.status_code, 200, enabled.json)
        self.codes = enabled.json['recovery_codes']

    def challenge(self, client=None):
        client = client or app.test_client()
        response = self.post('login', {'email': 'mfa@example.test', 'password': PASSWORD}, client)
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json['mfa_required'])
        self.assertNotIn('Set-Cookie', response.headers)
        return client, response.json['challenge']

    def test_enrollment_requires_password_and_confirmation_and_keeps_secret_private(self):
        self.assertEqual(self.post('mfa/setup', {'password': 'wrong'}).status_code, 401)
        self.post('mfa/setup', {'password': PASSWORD})
        self.assertEqual(self.post('mfa/enable', {'password': PASSWORD, 'code': 'bad'}).status_code, 401)
        self.assertFalse(self.client.get('/api/auth/mfa').json['enabled'])
        self.enroll()
        self.assertEqual(len(self.codes), 10)
        self.assertEqual(self.client.get('/api/auth/mfa').json, {'enabled': True, 'recovery_remaining': 10})
        profile = self.client.post('/api/documents/get', headers=HEADERS, json={'path': 'users/' + self.uid}).json
        self.assertNotIn(self.secret, str(profile))
        with connect() as db:
            hashed = db.execute('SELECT code_hash FROM mfa_recovery WHERE user_id=%s', (self.uid,)).fetchone()['code_hash']
        self.assertEqual(len(hashed), 64)
        self.assertNotIn(hashed, self.codes)

    def test_password_alone_never_grants_a_session_and_backup_is_single_use(self):
        self.enroll()
        client, challenge = self.challenge()
        self.assertIsNone(client.get('/api/auth/session').json['user'])
        denied = client.post('/api/documents/get', headers=HEADERS, json={'path': 'users/' + self.uid})
        self.assertEqual(denied.status_code, 401)
        self.assertEqual(self.post('mfa/verify', {'challenge': challenge, 'code': 'wrong'}, client).status_code, 401)
        result = self.post('mfa/verify', {'challenge': challenge, 'code': self.codes[0]}, client)
        self.assertEqual(result.status_code, 200)
        self.assertEqual(result.json['user']['uid'], self.uid)
        self.assertEqual(self.post('mfa/verify', {'challenge': challenge, 'code': self.codes[1]}, client).status_code, 401)
        other, again = self.challenge()
        self.assertEqual(self.post('mfa/verify', {'challenge': again, 'code': self.codes[0]}, other).status_code, 401)

    def test_skipping_registration_enrollment_does_not_enable_mfa(self):
        setup = self.post('mfa/setup', {'password': PASSWORD})
        self.assertEqual(setup.status_code, 200)
        self.assertIn(setup.json['secret'], setup.json['uri'])
        self.assertFalse(self.client.get('/api/auth/mfa').json['enabled'])
        # Displaying the QR code alone never protects the account or blocks login.
        client = app.test_client()
        result = self.post('login', {'email': 'mfa@example.test', 'password': PASSWORD}, client)
        self.assertIn('user', result.json)
        self.assertNotIn('mfa_required', result.json)
        self.assertEqual(client.get('/api/auth/session').json['user']['uid'], self.uid)

    def test_totp_code_cannot_be_replayed_in_another_challenge(self):
        self.enroll()
        client, challenge = self.challenge()
        at = (self.counter + 1) * 30
        code = totp.code_at(self.secret, self.counter + 1)
        with patch('totp.time.time', return_value=at):
            self.assertEqual(self.post('mfa/verify', {'challenge': challenge, 'code': code}, client).status_code, 200)
            other, again = self.challenge()
            self.assertEqual(self.post('mfa/verify', {'challenge': again, 'code': code}, other).status_code, 401)

    def test_expired_challenge_and_pending_setup_are_rejected(self):
        self.enroll()
        client, challenge = self.challenge()
        with connect() as db:
            db.execute("UPDATE mfa_challenges SET expires_at=now()-interval '1 second'")
        self.assertEqual(self.post('mfa/verify', {'challenge': challenge, 'code': self.codes[0]}, client).status_code, 401)
        self.assertEqual(self.post('mfa/disable', {'password': PASSWORD, 'code': self.codes[0]}).status_code, 200)
        self.post('mfa/setup', {'password': PASSWORD})
        with connect() as db:
            db.execute("UPDATE mfa SET pending_expires_at=now()-interval '1 second'")
        self.assertEqual(self.post('mfa/enable', {'password': PASSWORD, 'code': '123456'}).status_code, 409)

    def test_disable_requires_both_factors_and_revokes_other_sessions(self):
        other = app.test_client()
        self.post('login', {'email': 'mfa@example.test', 'password': PASSWORD}, other)
        self.enroll()
        self.assertIsNone(other.get('/api/auth/session').json['user'])
        self.assertEqual(self.post('mfa/disable', {'password': PASSWORD, 'code': 'bad'}).status_code, 401)
        self.assertEqual(self.post('mfa/disable', {'password': 'wrong', 'code': self.codes[0]}).status_code, 401)
        self.assertTrue(self.client.get('/api/auth/mfa').json['enabled'])
        self.assertEqual(self.post('mfa/disable', {'password': PASSWORD, 'code': self.codes[0]}).status_code, 200)
        response = self.post('login', {'email': 'mfa@example.test', 'password': PASSWORD}, app.test_client())
        self.assertIn('user', response.json)

    def test_recovery_rotation_invalidates_old_codes(self):
        self.enroll()
        renewed = self.post('mfa/recovery', {'password': PASSWORD, 'code': self.codes[0]})
        self.assertEqual(renewed.status_code, 200)
        client, challenge = self.challenge()
        self.assertEqual(self.post('mfa/verify', {'challenge': challenge, 'code': self.codes[1]}, client).status_code, 401)
        self.assertEqual(self.post('mfa/verify', {'challenge': challenge, 'code': renewed.json['recovery_codes'][0]}, client).status_code, 200)

    def test_bad_codes_are_rate_limited_across_persistent_requests(self):
        self.enroll()
        client, challenge = self.challenge()
        for _ in range(10):
            self.assertEqual(self.post('mfa/verify', {'challenge': challenge, 'code': 'bad'}, client).status_code, 401)
        self.assertEqual(self.post('mfa/verify', {'challenge': challenge, 'code': self.codes[0]}, client).status_code, 429)

    def test_concurrent_recovery_redemption_succeeds_once(self):
        self.enroll()
        _, first = self.challenge()
        _, second = self.challenge()
        def verify(challenge):
            return self.post('mfa/verify', {'challenge': challenge, 'code': self.codes[0]}, app.test_client()).status_code
        with ThreadPoolExecutor(max_workers=2) as pool:
            statuses = sorted(pool.map(verify, [first, second]))
        self.assertEqual(statuses, [200, 401])

    def test_mfa_state_is_not_writable_through_profile_documents(self):
        self.enroll()
        result = self.client.post('/api/documents/commit', headers=HEADERS, json={
            'requestId': 'mfa-profile-test', 'operations': [{'path': 'users/' + self.uid, 'action': 'set', 'data': {'mfa': False, 'secret': ''}}],
        })
        self.assertEqual(result.status_code, 400)
        self.assertTrue(self.client.get('/api/auth/mfa').json['enabled'])

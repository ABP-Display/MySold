"""Versioned AES-256-GCM envelopes. Keys never enter user documents or exports.

The server can decrypt data. Dates, types and opaque references remain indexed;
amounts, names, profile fields and TOTP seeds are encrypted at rest.
"""
import base64
import hashlib
import json
import os
from pathlib import Path
import secrets
import stat
import sys

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from psycopg.types.json import Jsonb

INDEX_FIELDS = frozenset({'date', 'type', 'createdAt', 'fromAccountId',
                         'toAccountId', 'holdingAccountId', 'categoryId',
                         'investmentId', 'managedByInvestments'})
PREFIX = 'aesgcm:v1:'


class EncryptionError(RuntimeError):
    pass


def key_path():
    return Path(os.getenv('MYSOLD_KEY_FILE', '/keys/master.key'))


def read_master():
    path = key_path()
    try:
        flags = os.O_RDONLY | getattr(os, 'O_NOFOLLOW', 0)
        fd = os.open(path, flags)
        with os.fdopen(fd, 'rb') as stream:
            info = os.fstat(stream.fileno())
            value = stream.read(33)
        if not stat.S_ISREG(info.st_mode) or len(value) != 32:
            raise EncryptionError('Invalid master key. Restore data/keys from backup.')
        if os.name != 'nt' and info.st_mode & 0o077:
            raise EncryptionError('Master key must have permissions 0600.')
        return value
    except OSError as error:
        raise EncryptionError('Master key unavailable. Restore data/keys; never replace a lost key.') from error


def initialize_key():
    """The Compose initializer is the only process allowed to create a key."""
    path = key_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.parent.is_symlink():
        raise EncryptionError('Refusing a symlink as key directory.')
    if os.name != 'nt':
        os.chmod(path.parent, 0o700)
    try:
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, 'O_NOFOLLOW', 0), 0o600)
    except FileExistsError:
        read_master()  # Never overwrite a malformed, incomplete or existing key.
    else:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(secrets.token_bytes(32))
            stream.flush()
            os.fsync(stream.fileno())
    if os.name != 'nt' and os.geteuid() == 0:
        os.chown(path, 10001, 10001)
        os.chown(path.parent, 10001, 10001)
    if os.name != 'nt':
        directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    read_master()


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True,
                      separators=(',', ':'), allow_nan=False).encode('utf-8')


def seal(key, value, aad):
    nonce = secrets.token_bytes(12)
    return b'\x01' + nonce + AESGCM(key).encrypt(nonce, value, aad)


def unseal(key, value, aad):
    value = bytes(value)
    if len(value) < 29 or value[0] != 1:
        raise EncryptionError('Unknown or truncated encrypted envelope.')
    try:
        return AESGCM(key).decrypt(value[1:13], value[13:], aad)
    except Exception as error:
        raise EncryptionError('Encrypted data authentication failed. Check the key and backup.') from error


def metadata(data):
    return {field: data[field] for field in INDEX_FIELDS if field in data}


class Vault:
    def __init__(self, db):
        self.db, self.master, self.keys = db, read_master(), {}

    def user_key(self, uid):
        if uid not in self.keys:
            row = self.db.execute('SELECT wrapped_key FROM user_data_keys WHERE user_id=%s', (uid,)).fetchone()
            if not row:
                if self.db.execute('SELECT 1 FROM documents WHERE user_id=%s AND sealed_data IS NOT NULL LIMIT 1', (uid,)).fetchone():
                    raise EncryptionError('User encryption key is missing. Restore the database backup.')
                # The unique constraint handles concurrent first access. The
                # winning envelope is always read back, never cached pre-commit.
                key = secrets.token_bytes(32)
                wrapped = seal(self.master, key, canonical(['mysold', 'user-key', uid]))
                self.db.execute('INSERT INTO user_data_keys(user_id,wrapped_key) VALUES (%s,%s) ON CONFLICT DO NOTHING',
                                (uid, wrapped))
                row = self.db.execute('SELECT wrapped_key FROM user_data_keys WHERE user_id=%s', (uid,)).fetchone()
            self.keys[uid] = unseal(self.master, row['wrapped_key'], canonical(['mysold', 'user-key', uid]))
        return self.keys[uid]

    def encode(self, uid, path, data):
        index = metadata(data)
        encrypted = seal(self.user_key(uid), canonical(data), canonical(['mysold', 'document', uid, path, index]))
        return index, encrypted

    def decode(self, uid, row):
        # No plaintext fallback after startup migration: a damaged record must
        # fail closed rather than silently expose/accept an unencrypted payload.
        if row['sealed_data'] is None:
            raise EncryptionError('Unencrypted document: startup migration is required.')
        raw = unseal(self.user_key(uid), row['sealed_data'],
                     canonical(['mysold', 'document', uid, row['path'], row['data']]))
        return json.loads(raw)

    def mfa_seal(self, uid, secret):
        if secret is None:
            return None
        return PREFIX + base64.b64encode(seal(self.user_key(uid), secret.encode(),
                                              canonical(['mysold', 'totp', uid]))).decode('ascii')

    def mfa_open(self, uid, secret):
        if secret is None:
            return None
        if not secret.startswith(PREFIX):
            raise EncryptionError('Unencrypted TOTP seed: startup migration is required.')
        try:
            envelope = base64.b64decode(secret[len(PREFIX):], validate=True)
        except ValueError as error:
            raise EncryptionError('Malformed TOTP envelope.') from error
        return unseal(self.user_key(uid), envelope, canonical(['mysold', 'totp', uid])).decode()


def vault(db):
    # A connection belongs to one request/transaction, never a process-wide key
    # cache. Batch reads unwrap a user's DEK only once, even with 500 documents.
    if not hasattr(db, '_mysold_vault'):
        db._mysold_vault = Vault(db)
    return db._mysold_vault


def migrate_encryption(db):
    """Bounded, resumable conversion, before Gunicorn accepts requests.

    Session advisory lock serializes concurrent API starts; each committed batch
    contains ciphertext and replacement index metadata in the same transaction.
    """
    db.execute('SELECT pg_advisory_lock(714183092)')
    try:
        store = vault(db)
        fingerprint = hashlib.sha256(store.master).hexdigest()
        db.execute('INSERT INTO encryption_state(id,master_fingerprint) VALUES (1,%s) ON CONFLICT DO NOTHING', (fingerprint,))
        state = db.execute('SELECT master_fingerprint FROM encryption_state WHERE id=1').fetchone()
        if state['master_fingerprint'] != fingerprint:
            raise EncryptionError('Wrong master key. Restore the original data/keys backup.')
        # Verify every existing wrapped DEK in bounded pages, including empty
        # accounts, so replacing the key never starts a superficially healthy API.
        after = ''
        while True:
            rows = db.execute('SELECT user_id,wrapped_key FROM user_data_keys WHERE user_id>%s ORDER BY user_id LIMIT 200', (after,)).fetchall()
            if not rows:
                break
            for row in rows:
                unseal(store.master, row['wrapped_key'], canonical(['mysold', 'user-key', row['user_id']]))
            after = rows[-1]['user_id']
        db.commit()
        while True:
            rows = db.execute('SELECT user_id,path,data FROM documents WHERE sealed_data IS NULL ORDER BY user_id,path LIMIT 200 FOR UPDATE').fetchall()
            if not rows:
                break
            for row in rows:
                index, encrypted = store.encode(row['user_id'], row['path'], row['data'])
                db.execute('UPDATE documents SET data=%s,sealed_data=%s WHERE user_id=%s AND path=%s',
                           (Jsonb(index), encrypted, row['user_id'], row['path']))
            db.commit()
            store.keys.clear()
        while True:
            rows = db.execute("SELECT * FROM mfa WHERE (secret IS NOT NULL AND secret NOT LIKE 'aesgcm:v1:%%') OR (pending_secret IS NOT NULL AND pending_secret NOT LIKE 'aesgcm:v1:%%') LIMIT 200 FOR UPDATE").fetchall()
            if not rows:
                break
            for row in rows:
                values = [store.mfa_seal(row['user_id'], row[field]) if row[field] and not row[field].startswith(PREFIX) else row[field]
                          for field in ('secret', 'pending_secret')]
                db.execute('UPDATE mfa SET secret=%s,pending_secret=%s WHERE user_id=%s', (*values, row['user_id']))
            db.commit()
            store.keys.clear()
        # These retired tables can exist on instances that briefly used the
        # annual reference feature. Preserve them, but do not leave their old
        # financial JSON plaintext or reactivate any annual calculation.
        for table in ('annual_snapshots', 'annual_report_cache'):
            if not db.execute('SELECT to_regclass(%s) AS name', (table,)).fetchone()['name']:
                continue
            while True:
                rows = db.execute(f"SELECT user_id,year,data FROM {table} WHERE NOT (data ? '_mysold_encrypted') LIMIT 200 FOR UPDATE").fetchall()
                if not rows:
                    break
                for row in rows:
                    envelope = seal(store.user_key(row['user_id']), canonical(row['data']),
                                    canonical(['mysold', 'retired', table, row['user_id'], row['year']]))
                    db.execute(f'UPDATE {table} SET data=%s WHERE user_id=%s AND year=%s',
                               (Jsonb({'_mysold_encrypted': PREFIX + base64.b64encode(envelope).decode('ascii')}), row['user_id'], row['year']))
                db.commit()
                store.keys.clear()
        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.execute('SELECT pg_advisory_unlock(714183092)')
        db.commit()


if __name__ == '__main__':
    if sys.argv[1:] != ['init-key']:
        raise SystemExit('Usage: python encryption.py init-key')
    initialize_key()
    print('Encryption key ready (no secret logged).')

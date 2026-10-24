"""Opt-in PostgreSQL tests. Only uniquely labelled disposable resources are used."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
DOCKER = shutil.which('docker')
ENABLED = os.environ.get('MYSOLD_STORAGE_INTEGRATION') == '1' and DOCKER


@unittest.skipUnless(ENABLED, 'Set MYSOLD_STORAGE_INTEGRATION=1 to run isolated Docker tests')
class StorageIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.token = uuid.uuid4().hex[:12]
        self.prefix = 'mysold-storage-test-' + self.token
        self.containers, self.volumes = [], []
        self.code = (ROOT / 'scripts/data.sh').read_text(encoding='utf-8')
        self.addCleanup(self.cleanup_resources)

    def docker(self, *args, data=None, check=True):
        result = subprocess.run([DOCKER, *args], input=data, capture_output=True, timeout=180)
        if check and result.returncode:
            self.fail(result.stderr.decode(errors='replace')[-2000:])
        return result

    def volume(self, suffix):
        name = self.prefix + '-' + suffix
        self.docker('volume', 'create', '--label', 'mysold.storage-test=' + self.token, name)
        self.volumes.append(name)
        return name

    def database(self, suffix, volume, nested=False):
        name = self.prefix + '-' + suffix
        target = '/instance' if nested else '/var/lib/postgresql/data'
        args = ['run', '-d', '--name', name, '--network', 'none', '--memory', '256m',
                '--label', 'mysold.storage-test=' + self.token,
                '-e', 'POSTGRES_USER=mysold', '-e', 'POSTGRES_DB=mysold_test',
                '-e', 'POSTGRES_PASSWORD=disposable-storage-fixture',
                '--mount', f'type=volume,source={volume},target={target}']
        if nested:
            args += ['-e', 'PGDATA=/instance/postgres']
        self.docker(*args, 'postgres:17-alpine')
        self.containers.append(name)
        self.wait_db(name)
        return name

    def wait_db(self, name):
        deadline = time.monotonic() + 60
        while time.monotonic() < deadline:
            # The image briefly starts a temporary server during initdb. Wait
            # for the final PID 1 server, not that short-lived bootstrap server.
            if self.docker('exec', name, '/bin/sh', '-c', '[ "$(cat /proc/1/comm)" = postgres ] && pg_isready -U mysold -d mysold_test', check=False).returncode == 0:
                return
            time.sleep(.5)
        self.fail('PostgreSQL did not start')

    def sql(self, name, query):
        return self.docker('exec', name, 'psql', '-X', '-U', 'mysold', '-d', 'mysold_test', '-At', '-v', 'ON_ERROR_STOP=1', '-c', query).stdout.strip()

    def internal(self, name, mode, data=None, check=True):
        return self.docker('exec', '-i', '-e', 'MYSOLD_STORAGE_TASK=1', name,
                           '/bin/sh', '-c', self.code, '--', mode, data=data, check=check)

    def copy(self, old, new, check=True):
        return self.docker('run', '--rm', '--network', 'none', '-e', 'MYSOLD_STORAGE_TASK=1',
                           '--mount', f'type=volume,source={old},target=/source,readonly',
                           '--mount', f'type=volume,source={new},target=/destination',
                           '--entrypoint', '/bin/sh', 'postgres:17-alpine', '-c', self.code, '--', '_copy', check=check)

    def cleanup_resources(self):
        # Never remove an object unless it carries this test run's unique label.
        for name in reversed(self.containers):
            result = self.docker('inspect', '--format', '{{index .Config.Labels "mysold.storage-test"}}', name, check=False)
            if result.returncode == 0 and result.stdout.decode().strip() == self.token:
                self.docker('rm', '-f', '-v', name, check=False)
        for name in reversed(self.volumes):
            result = self.docker('volume', 'inspect', '--format', '{{index .Labels "mysold.storage-test"}}', name, check=False)
            if result.returncode == 0 and result.stdout.decode().strip() == self.token:
                self.docker('volume', 'rm', name, check=False)

    def test_cold_migration_dump_restore_and_restart_preserve_accounts_and_mfa(self):
        old = self.volume('original')
        new = self.volume('data')
        restored = self.volume('restored')
        original = self.database('original', old)
        self.docker('exec', '-i', original, 'psql', '-U', 'mysold', '-d', 'mysold_test', '-v', 'ON_ERROR_STOP=1', data=(ROOT / 'backend/schema.sql').read_bytes())
        self.sql(original, "INSERT INTO users(id,email,password_hash) VALUES ('fixture','test@example.invalid','fixture-hash'); INSERT INTO documents(user_id,path,collection,data) VALUES ('fixture','users/fixture/accounts/current','accounts','{\"balance\":123.45}'); INSERT INTO mfa(user_id,secret) VALUES ('fixture','TEST_SECRET'); INSERT INTO sessions(token_hash,user_id,expires_at) VALUES ('fixture-session','fixture','2030-01-01')")
        query = "SELECT email || ':' || password_hash || ':' || (SELECT data->>'balance' FROM documents LIMIT 1) || ':' || (SELECT secret FROM mfa LIMIT 1) || ':' || (SELECT token_hash FROM sessions LIMIT 1) FROM users"
        expected = self.sql(original, query)
        active_copy = self.copy(old, new, check=False)
        self.assertNotEqual(active_copy.returncode, 0, 'A running source must never be copied')
        self.docker('stop', '--time', '120', original)
        self.copy(old, new)
        duplicate = self.copy(old, new, check=False)
        self.assertNotEqual(duplicate.returncode, 0, 'Never overwrite an existing destination')
        migrated = self.database('migrated', new, nested=True)
        self.assertEqual(self.sql(migrated, query), expected)
        dump = self.internal(migrated, '_dump').stdout
        self.assertTrue(dump.startswith(b'PGDMP'))
        refused = self.internal(migrated, '_restore', dump, check=False)
        self.assertNotEqual(refused.returncode, 0)
        self.assertEqual(self.sql(migrated, query), expected)
        target = self.database('restored', restored)
        invalid = self.internal(target, '_restore', b'not-a-database', check=False)
        self.assertNotEqual(invalid.returncode, 0)
        self.assertEqual(self.sql(target, "SELECT count(*) FROM pg_tables WHERE schemaname='public'"), b'0')
        self.internal(target, '_restore', dump)
        self.assertEqual(self.sql(target, query), expected)
        self.docker('restart', target)
        self.wait_db(target)
        self.assertEqual(self.sql(target, query), expected)
        self.docker('start', original)
        self.wait_db(original)
        self.assertEqual(self.sql(original, query), expected, 'Original volume must remain usable')

    def test_compose_preserves_legacy_default_and_uses_bind_only_when_selected(self):
        for storage in (None, './data/postgres'):
            with self.subTest(storage=storage), tempfile.TemporaryDirectory() as temporary:
                env = Path(temporary) / '.env'
                env.write_text('POSTGRES_PASSWORD=fixture-only\n' + (f'POSTGRES_STORAGE={storage}\n' if storage else ''))
                process_env = os.environ.copy()
                process_env.pop('POSTGRES_STORAGE', None)
                result = subprocess.run([DOCKER, 'compose', '--project-directory', str(ROOT), '--env-file', str(env), '-f', str(ROOT / 'compose.yaml'), 'config', '--format', 'json'], capture_output=True, env=process_env, check=True)
                config = json.loads(result.stdout)
                mount = next(m for m in config['services']['db']['volumes'] if m['target'] == '/var/lib/postgresql/data')
                self.assertEqual(mount['type'], 'bind' if storage else 'volume')
                if storage:
                    self.assertTrue(mount['source'].replace('\\', '/').endswith('/data/postgres'))
                else:
                    self.assertEqual(mount['source'], 'postgres_data')

    @unittest.skipUnless(os.name == 'posix' and hasattr(os, 'geteuid') and os.geteuid() == 0,
                         'Full host bind-mount test requires a Linux root test process')
    def test_real_compose_maintenance_workflow(self):
        def fixture(suffix, folder_storage=False):
            temporary = tempfile.TemporaryDirectory(prefix='mysold-compose-test-')
            directory = Path(temporary.name)

            def cleanup():
                self.cleanup_resources()
                temporary.cleanup()

            self.addCleanup(cleanup)
            (directory / 'scripts').mkdir()
            (directory / 'scripts/data.sh').write_text(self.code)
            project = self.prefix + '-' + suffix
            labels = {'mysold.storage-test': self.token}
            db = {'image': 'postgres:17-alpine', 'network_mode': 'none', 'labels': labels,
                  'environment': {'POSTGRES_USER': 'mysold', 'POSTGRES_DB': 'mysold_test',
                                  'POSTGRES_PASSWORD': '${POSTGRES_PASSWORD}'},
                  'volumes': ['${POSTGRES_STORAGE:-postgres_data}:/var/lib/postgresql/data'],
                  'healthcheck': {'test': ['CMD-SHELL', '[ "$$(cat /proc/1/comm)" = postgres ] && pg_isready -U mysold -d mysold_test'],
                                  'interval': '1s', 'timeout': '3s', 'retries': 60}}
            idle = {'image': 'postgres:17-alpine', 'network_mode': 'none', 'labels': labels,
                    'entrypoint': ['/bin/sh', '-c'], 'command': ['sleep 3600']}
            config = {'name': project, 'services': {'db': db, 'api': idle, 'web': idle},
                      'volumes': {'postgres_data': {'labels': labels}}}
            (directory / 'compose.yaml').write_text(json.dumps(config))
            (directory / '.env').write_text('POSTGRES_PASSWORD=isolated-cli-fixture\nAPP_ORIGIN=https://example.invalid\n' +
                                          ('POSTGRES_STORAGE=./data/postgres\n' if folder_storage else ''))
            (directory / '.env').chmod(0o600)
            self.containers.append(project + '-db-1')
            self.volumes.append(project + '_postgres_data')
            return directory

        def compose(directory, *args):
            project = json.loads((directory / 'compose.yaml').read_text())['name']
            return self.docker('compose', '--project-name', project, '--project-directory', str(directory), '--env-file', str(directory / '.env'),
                               '-f', str(directory / 'compose.yaml'), *args)

        def maintain(directory, *args, check=True):
            project = json.loads((directory / 'compose.yaml').read_text())['name']
            assert project.startswith(self.prefix + '-')
            result = subprocess.run(['sh', str(directory / 'scripts/data.sh'), *map(str, args)],
                                    cwd=directory, capture_output=True, timeout=180,
                                    env={**os.environ, 'COMPOSE_PROJECT_NAME': project})
            if check and result.returncode:
                self.fail(result.stderr.decode(errors='replace')[-2500:])
            return result

        source = fixture('cli')
        compose(source, 'up', '-d', '--wait', '--wait-timeout', '120', 'db')
        original_id = compose(source, 'ps', '-q', 'db').stdout.decode().strip()
        self.sql(original_id, "CREATE TABLE fixture(id integer PRIMARY KEY, value text); INSERT INTO fixture VALUES (1,'preserved')")
        maintain(source, 'backup')
        archive = next((source / 'data/backups').glob('*.dump'))
        self.assertEqual(archive.stat().st_mode & 0o777, 0o600)
        maintain(source, 'migrate')
        self.assertIn('POSTGRES_STORAGE=./data/postgres', (source / '.env').read_text())
        self.assertEqual((source / 'data/config/instance.env').read_text(), (source / '.env').read_text())
        compose(source, 'up', '-d', '--wait', '--wait-timeout', '120', 'db')
        new_id = compose(source, 'ps', '-q', 'db').stdout.decode().strip()
        self.assertEqual(self.sql(new_id, 'SELECT value FROM fixture WHERE id=1'), b'preserved')
        self.assertNotEqual(maintain(source, 'migrate', check=False).returncode, 0)
        self.assertEqual(self.sql(new_id, 'SELECT value FROM fixture WHERE id=1'), b'preserved')
        target = fixture('cli-restore', folder_storage=True)
        settings = target / '.env'
        settings.write_text(settings.read_text().replace('isolated-cli-fixture', 'different-target-secret'))
        maintain(target, 'restore', archive)
        restored_id = compose(target, 'ps', '-q', 'db').stdout.decode().strip()
        self.assertEqual(self.sql(restored_id, 'SELECT value FROM fixture WHERE id=1'), b'preserved')
        self.assertNotEqual(maintain(target, 'restore', archive, check=False).returncode, 0)
        self.assertEqual(self.sql(restored_id, 'SELECT value FROM fixture WHERE id=1'), b'preserved')


if __name__ == '__main__':
    unittest.main()

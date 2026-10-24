import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


@unittest.skipUnless(os.name == 'posix', 'Linux/POSIX maintenance test')
class DataShellTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / 'scripts').mkdir()
        (self.root / 'bin').mkdir()
        shutil.copyfile(Path(__file__).with_name('data.sh'), self.root / 'scripts/data.sh')
        self.original = '# private settings\nPOSTGRES_PASSWORD=existing-test-secret\nAPP_ORIGIN=https://example.test\n'
        (self.root / '.env').write_text(self.original)
        (self.root / '.env').chmod(0o600)
        (self.root / 'compose.yaml').write_text('name: test-fixture\n')
        self.env = os.environ.copy()
        self.env.update(PATH=str(self.root / 'bin') + os.pathsep + self.env['PATH'], FIXTURE_ROOT=str(self.root))
        fake = self.root / 'bin/docker'
        fake.write_text('#!' + sys.executable + '\n' + r'''
import json, os, sys
from pathlib import Path
root=Path(os.environ['FIXTURE_ROOT']); args=sys.argv[1:]
def event(name):
    with (root/'events').open('a') as f: f.write(name+'\n')
if args[0]=='compose':
    if 'ps' in args:
        if args[-1]=='db':
            if os.environ.get('MISSING_DB')!='1' or (root/'created-db').exists(): print('fixture-db')
        elif os.environ.get('RUNNING_APPS')=='1': print('fixture-api')
    elif 'stop' in args: event('stop')
    elif 'up' in args: event('up')
    elif 'create' in args:
        event('create'); (root/'created-db').touch()
    elif 'exec' in args:
        if args[-1]=='_dump':
            event('dump'); sys.stdout.buffer.write(b'PGDMP\x00fixture')
        elif args[-1]=='_restore':
            event('restore'); (root/'restored-input').write_bytes(sys.stdin.buffer.read())
        elif 'pg_restore' in args:
            event('validate'); sys.stdin.buffer.read()
            if os.environ.get('INVALID_DUMP')=='1': sys.exit(1)
elif args[0]=='inspect':
    if '.Config.Image' in args[2]: print('postgres:17-alpine')
    elif os.environ.get('ALREADY_BIND')!='1': print('fixture-original-volume')
elif args[0]=='run':
    event('copy')
    assert '--network' in args and 'none' in args
    assert any('source=fixture-original-volume,target=/source,readonly' in a for a in args)
    assert (root/'.env').read_text()==os.environ.get('EXPECTED_CONFIG', (root/'.env').read_text())
    if os.environ.get('COPY_FAIL')=='1': sys.exit(1)
    (root/'data/postgres').mkdir(parents=True)
    (root/'data/postgres/PG_VERSION').write_text('17\n')
''')
        fake.chmod(0o755)

    def run_script(self, *args, **env):
        return subprocess.run(['sh', str(self.root / 'scripts/data.sh'), *args],
                              cwd=self.root, text=True, capture_output=True, env={**self.env, **env})

    def events(self):
        path = self.root / 'events'
        return path.read_text().splitlines() if path.exists() else []

    def test_migration_switches_only_after_success_and_preserves_credentials(self):
        result = self.run_script('migrate', EXPECTED_CONFIG=self.original)
        self.assertEqual(result.returncode, 0, result.stderr)
        updated = (self.root / '.env').read_text()
        self.assertEqual(updated, self.original + 'POSTGRES_STORAGE=./data/postgres\n')
        self.assertEqual(self.events(), ['stop', 'copy'])
        self.assertEqual((self.root / 'data/config/instance.env').read_text(), updated)
        self.assertEqual((self.root / '.env').stat().st_mode & 0o777, 0o600)

    def test_failed_copy_never_switches_config(self):
        result = self.run_script('migrate', COPY_FAIL='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.root / '.env').read_text(), self.original)
        self.assertEqual(self.events(), ['stop', 'copy'])

    def test_removed_db_container_is_recreated_without_starting_before_copy(self):
        result = self.run_script('migrate', MISSING_DB='1')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.events(), ['create', 'stop', 'copy'])

    def test_nonempty_destination_is_rejected_before_stopping(self):
        destination = self.root / 'data/postgres'
        destination.mkdir(parents=True)
        (destination / 'keep').write_text('keep')
        result = self.run_script('migrate')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.events(), [])
        self.assertEqual((destination / 'keep').read_text(), 'keep')

    def test_already_bound_storage_is_not_migrated(self):
        result = self.run_script('migrate', ALREADY_BIND='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.events(), [])

    def test_export_is_private_and_complete_with_matching_config(self):
        result = self.run_script('backup')
        self.assertEqual(result.returncode, 0, result.stderr)
        backups = list((self.root / 'data/backups').glob('*.dump'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].stat().st_mode & 0o777, 0o600)
        self.assertEqual((self.root / 'data/config/instance.env').read_text(), self.original)
        self.assertNotIn('existing-test-secret', result.stdout + result.stderr)

    def test_invalid_export_is_not_published(self):
        result = self.run_script('backup', INVALID_DUMP='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(list((self.root / 'data/backups').iterdir()), [])

    def test_restore_refuses_running_app_before_starting_db(self):
        archive = self.root / 'example.dump'
        archive.write_bytes(b'PGDMP\x00test')
        result = self.run_script('restore', str(archive), RUNNING_APPS='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.events(), [])

    def test_restore_streams_binary_without_modifying_source_file(self):
        archive = self.root / 'example.dump'
        content = b'PGDMP\x00\xfftest'
        archive.write_bytes(content)
        result = self.run_script('restore', str(archive))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / 'restored-input').read_bytes(), content)
        self.assertEqual(archive.read_bytes(), content)


if __name__ == '__main__':
    unittest.main()

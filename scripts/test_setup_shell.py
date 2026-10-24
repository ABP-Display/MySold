import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


@unittest.skipUnless(os.name == 'posix', 'Linux/POSIX setup test')
class ShellSetupTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / 'scripts').mkdir()
        shutil.copyfile(Path(__file__).with_name('setup.sh'), self.root / 'scripts/setup.sh')
        (self.root / '.env.example').write_text('POSTGRES_PASSWORD=REPLACE_WITH_A_RANDOM_PASSWORD\nPOSTGRES_STORAGE=./data/postgres\nAPP_ORIGIN=https://example.test\n')

    def run_setup(self):
        return subprocess.run(['sh', str(self.root / 'scripts/setup.sh')], cwd='/', text=True, capture_output=True)

    def test_new_secret_permissions_and_rerun_preserve_configuration(self):
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stderr)
        target = self.root / '.env'
        original = target.read_text()
        secret = re.search(r'POSTGRES_PASSWORD=([a-f0-9]{64})', original)[1]
        self.assertNotIn(secret, result.stdout + result.stderr)
        self.assertEqual(target.stat().st_mode & 0o777, 0o600)
        self.assertIn('POSTGRES_STORAGE=./data/postgres', original)
        self.assertEqual((self.root / 'data/config/instance.env').read_text(), original)
        self.assertEqual((self.root / 'data/config/instance.env').stat().st_mode & 0o777, 0o600)
        self.assertEqual((self.root / 'data/backups').stat().st_mode & 0o777, 0o700)
        self.assertEqual(self.run_setup().returncode, 0)
        self.assertEqual(target.read_text(), original)

    def test_invalid_existing_env_is_preserved_and_rejected(self):
        for value in ('', 'WEB_PORT=28085\n', 'POSTGRES_PASSWORD=\nNEXT=value\n',
                      'POSTGRES_PASSWORD= # empty\n', 'POSTGRES_PASSWORD=""\n',
                      "POSTGRES_PASSWORD='' # empty\n", 'POSTGRES_PASSWORD=REPLACE_WITH_A_RANDOM_PASSWORD\n'):
            with self.subTest(value=value):
                target = self.root / '.env'
                target.write_text(value)
                self.assertNotEqual(self.run_setup().returncode, 0)
                self.assertEqual(target.read_text(), value)

    def test_quoted_existing_secret_is_never_printed_or_changed(self):
        value = "POSTGRES_PASSWORD='existing secret # stays'\nAPP_ORIGIN=https://personal.test\n"
        target = self.root / '.env'
        target.write_text(value)
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(target.read_text(), value)
        self.assertNotIn('existing secret', result.stdout + result.stderr)
        self.assertNotIn('POSTGRES_STORAGE', target.read_text())
        self.assertEqual((self.root / 'data/config/instance.env').read_text(), value)

    def test_editing_site_configuration_refreshes_private_copy_only(self):
        self.assertEqual(self.run_setup().returncode, 0)
        target = self.root / '.env'
        changed = target.read_text().replace('https://example.test', 'https://new.example.test')
        target.write_text(changed)
        self.assertEqual(self.run_setup().returncode, 0)
        self.assertEqual(target.read_text(), changed)
        self.assertEqual((self.root / 'data/config/instance.env').read_text(), changed)


if __name__ == '__main__':
    unittest.main()

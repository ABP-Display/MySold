"""Opt-in full Compose installation test; uses its own project and storage only."""
import hashlib
import http.cookiejar
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[1]
DOCKER = shutil.which('docker')


@unittest.skipUnless(os.getenv('MYSOLD_INSTALLATION_TEST') == '1' and DOCKER,
                     'Set MYSOLD_INSTALLATION_TEST=1 to test an isolated installation')
class InstallationTests(unittest.TestCase):
    def setUp(self):
        self.project = 'mysold-install-test-' + uuid.uuid4().hex[:12]
        self.folder = tempfile.TemporaryDirectory(prefix=self.project + '-')
        self.addCleanup(self.folder.cleanup)
        self.directory = Path(self.folder.name)
        self.compose_file = self.directory / 'compose.yaml'
        self.compose_file.write_text((ROOT / 'compose.yaml').read_text(), encoding='utf-8')
        # No user .env or exported project configuration may enter this fixture.
        self.env = {k: v for k, v in os.environ.items() if not k.startswith('COMPOSE_')}
        for key in ('POSTGRES_DB', 'POSTGRES_USER', 'POSTGRES_PASSWORD', 'APP_ORIGIN',
                    'WEB_PORT', 'COOKIE_SECURE', 'ALLOW_REGISTRATION', 'MYSOLD_REPOSITORY'):
            self.env.pop(key, None)
        self.addCleanup(self.remove_project)
        config = json.loads(self.compose('config', '--no-interpolate', '--format', 'json').stdout)
        db_mounts = config['services']['db']['volumes']
        self.assertEqual({Path(v['source']).name for v in db_mounts},
                         {'postgres', 'config', 'backups'})
        self.assertTrue(all(v['type'] == 'bind' for v in db_mounts))
        config['name'] = self.project
        services = config['services']
        services['api']['build']['context'] = str(ROOT / 'backend')
        services['web']['build']['context'] = str(ROOT / 'frontend')
        if os.getenv('MYSOLD_TEST_WEB_IMAGE'):
            services['web'].pop('build')
            services['web']['image'] = os.environ['MYSOLD_TEST_WEB_IMAGE']
        services['web']['ports'] = [{'target': 8080, 'published': '0',
                                     'host_ip': '127.0.0.1', 'protocol': 'tcp'}]
        for service in services.values():
            service['restart'] = 'no'
            service['labels'] = {'mysold.installation-test': self.project}
        # Windows bind mounts do not enforce Unix ownership. Use isolated named
        # volumes there; the root Linux CI exercises the actual host data folders.
        if os.name == 'nt':
            config['volumes'] = {n: {'labels': {'mysold.installation-test': self.project}}
                                 for n in ('postgres', 'config', 'backups')}
            for service in services.values():
                for mount in service.get('volumes', []):
                    mount['source'] = Path(mount['source']).name
                    mount['type'] = 'volume'
                    mount.pop('bind', None)
        self.compose_file.write_text(json.dumps(config), encoding='utf-8')

    def compose(self, *args, check=True, data=None):
        result = subprocess.run([DOCKER, 'compose', '--project-name', self.project,
                                 '--project-directory', str(self.directory),
                                 '-f', str(self.compose_file), *args],
                                env=self.env, input=data, capture_output=True, timeout=600)
        if check and result.returncode:
            # Do not dump the rendered Compose configuration or any credentials.
            self.fail(result.stderr.decode(errors='replace')[-4000:])
        return result

    def remove_project(self):
        # Explicitly named, uniquely labelled test resources, never the live stack.
        self.compose('down', '--volumes', '--remove-orphans', check=False)

    def request(self, path, body=None, opener=None):
        opener = opener or urllib.request.build_opener()
        headers = {'Origin': 'http://localhost:28085', 'X-MySold-Request': '1'}
        if body is not None:
            headers['Content-Type'] = 'application/json'
        req = urllib.request.Request(self.url + path, headers=headers,
                                     data=None if body is None else json.dumps(body).encode())
        with opener.open(req, timeout=20) as response:
            return json.load(response)

    def secret_fingerprint(self):
        result = self.compose('exec', '-T', 'api', 'python', '-c',
                              'import hashlib,os,pathlib; '
                              'p=pathlib.Path(os.environ["POSTGRES_PASSWORD_FILE"]); '
                              'assert p.stat().st_mode & 0o777 == 0o600; '
                              'print(hashlib.sha256(p.read_bytes()).hexdigest())')
        return result.stdout.strip()

    def start(self, *extra):
        self.compose('up', '-d', '--build', '--wait', '--wait-timeout', '120', *extra)
        address = self.compose('port', 'web', '8080').stdout.decode().strip()
        self.url = 'http://' + address

    def test_fresh_installation_rebuild_and_example_configuration(self):
        self.assertFalse((self.directory / '.env').exists())
        self.start()
        self.assertEqual(self.request('/api/health'), {'status': 'ok'})
        first_secret = self.secret_fingerprint()
        cookies = http.cookiejar.CookieJar()
        client = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cookies))
        password = 'Installation-test-password-123!'
        user = self.request('/api/auth/register', {
            'email': 'installation@example.test', 'password': password,
            'profile': {'firstName': 'Installation', 'pin': hashlib.sha256(b'123456').hexdigest()},
        }, client)['user']
        self.compose('exec', '-T', 'db', 'sh', '-ec',
                     'umask 077; pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" '
                     '-Fc -f /backups/installation.dump; pg_restore --list '
                     '/backups/installation.dump >/dev/null')
        self.compose('down')
        self.start('--force-recreate')
        self.assertEqual(first_secret, self.secret_fingerprint())
        logged_in = self.request('/api/auth/login', {
            'email': 'installation@example.test', 'password': password}, client)
        self.assertEqual(user['uid'], logged_in['user']['uid'])
        # Merely copying the example must remain sufficient: the empty optional
        # password never replaces the generated secret or existing account.
        shutil.copyfile(ROOT / '.env.example', self.directory / '.env')
        self.start('--force-recreate')
        self.assertEqual(first_secret, self.secret_fingerprint())
        self.assertEqual(user['uid'], self.request('/api/auth/login', {
            'email': 'installation@example.test', 'password': password}, client)['user']['uid'])
        # The normal API suites run against an explicitly separate test database.
        self.compose('exec', '-T', 'db', 'createdb', '-U', 'mysold', 'mysold_test')
        self.compose('exec', '-T', '-e', 'POSTGRES_DB=mysold_test', 'api',
                     'python', '-m', 'unittest', '-v',
                     'test_api', 'test_mfa', 'test_totp', 'test_origin_policy')
        self.env['POSTGRES_PASSWORD'] = 'a-different-secret'
        self.compose('stop', 'api', 'web')
        self.compose('up', '-d', '--force-recreate', 'db')
        failure = self.compose('up', '-d', '--wait', '--wait-timeout', '15', 'db', check=False)
        self.assertNotEqual(failure.returncode, 0)
        self.env.pop('POSTGRES_PASSWORD')
        self.start('--force-recreate')
        self.assertEqual(first_secret, self.secret_fingerprint())


if __name__ == '__main__':
    unittest.main()

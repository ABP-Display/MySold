"""Opt-in TLS integration tests. No real certificates, API, database or user data."""
import http.client
import json
import os
from pathlib import Path
import shutil
import socket
import ssl
import subprocess
import tempfile
import time
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[2]
DOCKER = shutil.which('docker')
OPENSSL = shutil.which('openssl') or (
    r'C:\Program Files\Git\usr\bin\openssl.exe' if os.name == 'nt' else None)


@unittest.skipUnless(os.getenv('MYSOLD_TLS_TEST') == '1' and DOCKER and OPENSSL,
                     'Set MYSOLD_TLS_TEST=1; Docker and OpenSSL are required')
class NginxTlsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.folder = tempfile.TemporaryDirectory(prefix='mysold-tls-fixture-')
        cls.base = Path(cls.folder.name)
        cls.prefix = 'mysold-tls-test-' + uuid.uuid4().hex[:12]
        cls.network = cls.prefix + '-net'
        cls.image = os.getenv('MYSOLD_NGINX_TEST_IMAGE', 'nginxinc/nginx-unprivileged:stable-alpine')
        cls.gid = str(os.getgid() if hasattr(os, 'getgid') else 101)
        cls.containers = []
        cls.addClassCleanup(cls.cleanup)
        cls.run_command([DOCKER, 'network', 'create', cls.network])
        cls.webroot = cls.base / 'web'
        cls.webroot.mkdir()
        cls.webroot.chmod(0o755)
        index = cls.webroot / 'index.html'
        index.write_text('<h1>MySold TLS fixture</h1>', encoding='utf-8')
        index.chmod(0o644)
        cls.req = cls.base / 'openssl.conf'
        cls.req.write_text('[req]\ndistinguished_name=dn\n[dn]\n', encoding='utf-8')
        cls.run_command([OPENSSL, 'req', '-x509', '-newkey', 'rsa:2048', '-nodes',
                         '-sha256', '-days', '2', '-subj', '/CN=MySold test-only CA',
                         '-config', str(cls.req), '-addext', 'basicConstraints=critical,CA:TRUE',
                         '-addext', 'keyUsage=critical,keyCertSign,cRLSign',
                         '-keyout', str(cls.base / 'ca.key'), '-out', str(cls.base / 'ca.pem')])
        cls.certs = cls.certificate('certs', 1)
        cls.renewed = cls.certificate('renewed', 2)
        fake = cls.base / 'api.conf'
        fake.write_text('server { listen 8000; location = / { default_type text/html; '
                        'return 200 "<h1>MySold public fixture</h1>"; } '
                        'location / { default_type application/json; '
                        'return 200 "{\\"fixture\\":true}"; } }', encoding='utf-8')
        fake.chmod(0o644)
        cls.start('api', ['--network-alias', 'api', '--mount',
                         f'type=bind,source={fake},target=/etc/nginx/conf.d/default.conf,readonly'])

    @classmethod
    def cleanup(cls):
        for container in reversed(cls.containers):
            subprocess.run([DOCKER, 'rm', '-f', container], capture_output=True, timeout=30)
        subprocess.run([DOCKER, 'network', 'rm', cls.network], capture_output=True, timeout=30)
        cls.folder.cleanup()

    @staticmethod
    def run_command(args, *, check=True, env=None):
        result = subprocess.run(args, capture_output=True, text=True, timeout=90, env=env)
        if check and result.returncode:
            raise AssertionError('Test command failed: ' + result.stderr[-2500:])
        return result

    @classmethod
    def certificate(cls, name, serial):
        target = cls.base / name
        target.mkdir(mode=0o750)
        target.chmod(0o750)
        extension = target / 'extensions.conf'
        extension.write_text('subjectAltName=DNS:mysold.test\nbasicConstraints=critical,CA:FALSE\n'
                             'keyUsage=critical,digitalSignature,keyEncipherment\n'
                             'extendedKeyUsage=serverAuth\n', encoding='utf-8')
        cls.run_command([OPENSSL, 'req', '-new', '-newkey', 'rsa:2048', '-nodes',
                         '-subj', '/CN=mysold.test', '-config', str(cls.req),
                         '-keyout', str(target / 'privkey.pem'), '-out', str(target / 'server.csr')])
        cls.run_command([OPENSSL, 'x509', '-req', '-in', str(target / 'server.csr'),
                         '-CA', str(cls.base / 'ca.pem'), '-CAkey', str(cls.base / 'ca.key'),
                         '-set_serial', str(serial), '-days', '2', '-sha256',
                         '-extfile', str(extension), '-out', str(target / 'fullchain.pem')])
        (target / 'privkey.pem').chmod(0o640)
        (target / 'fullchain.pem').chmod(0o640)
        return target

    @classmethod
    def start(cls, name, options):
        container = cls.prefix + '-' + name + '-' + uuid.uuid4().hex[:6]
        cls.containers.append(container)
        cls.run_command([DOCKER, 'run', '-d', '--name', container, '--network', cls.network,
                         '--read-only', '--tmpfs', '/tmp', '--tmpfs', '/var/cache/nginx',
                         '--tmpfs', '/var/run', '--cap-drop', 'ALL',
                         '--security-opt', 'no-new-privileges:true', *options, cls.image])
        return container

    @classmethod
    def start_web(cls, label, certs=None):
        options = ['--publish', '127.0.0.1::8080', '--mount',
                   f'type=bind,source={ROOT / "frontend/nginx.conf"},target=/etc/nginx/conf.d/default.conf,readonly',
                   '--mount', f'type=bind,source={cls.webroot},target=/usr/share/nginx/html,readonly']
        if certs is not None:
            options += ['--publish', '127.0.0.1::8443', '--group-add', cls.gid,
                        '--mount', f'type=bind,source={ROOT / "frontend/nginx-tls.conf"},target=/etc/nginx/mysold-tls/https.conf,readonly',
                        '--mount', f'type=bind,source={certs},target=/etc/nginx/mysold-certs,readonly']
        return cls.start(label, options)

    @classmethod
    def port(cls, container, port):
        output = cls.run_command([DOCKER, 'port', container, str(port)]).stdout.strip()
        return int(output.splitlines()[0].rsplit(':', 1)[1])

    @classmethod
    def wait_http(cls, container):
        port = cls.port(container, 8080)
        for _ in range(60):
            try:
                with socket.create_connection(('127.0.0.1', port), timeout=1):
                    return port
            except OSError:
                time.sleep(.1)
        raise AssertionError('Fixture did not start: ' + cls.run_command([DOCKER, 'logs', container]).stderr[-1500:])

    @staticmethod
    def request(port, *, tls=False, cafile=None, hostname='mysold.test', path='/', headers=None):
        stream = socket.create_connection(('127.0.0.1', port), timeout=5)
        try:
            peer = None
            if tls:
                context = ssl.create_default_context(cafile=str(cafile) if cafile else None)
                stream = context.wrap_socket(stream, server_hostname=hostname)
                peer = stream.getpeercert()
            fields = {'Host': hostname, 'Connection': 'close', **(headers or {})}
            request = f'GET {path} HTTP/1.1\r\n' + ''.join(f'{k}: {v}\r\n' for k, v in fields.items()) + '\r\n'
            stream.sendall(request.encode('ascii'))
            response = http.client.HTTPResponse(stream)
            response.begin()
            return response.status, dict(response.getheaders()), response.read(), peer
        finally:
            stream.close()

    def test_http_default_starts_without_any_certificates(self):
        container = self.start_web('http')
        port = self.wait_http(container)
        status, headers, body, _ = self.request(port, path='/app/')
        self.assertEqual(status, 200)
        self.assertIn(b'MySold TLS fixture', body)
        self.assertNotIn('Strict-Transport-Security', headers)
        self.assertIn('noindex', headers['X-Robots-Tag'])
        self.assertIn(b'MySold public fixture', self.request(port)[2])
        self.assertNotIn('X-Robots-Tag', self.request(port)[1])
        config = self.run_command([DOCKER, 'exec', container, 'nginx', '-T'])
        self.assertNotIn('listen 8443 ssl', config.stdout)

    def test_tls_verifies_certificate_and_hostname_while_http_keeps_working(self):
        container = self.start_web('https', self.certs)
        http_port = self.wait_http(container)
        https_port = self.port(container, 8443)
        status, headers, body, _ = self.request(https_port, tls=True, cafile=self.base / 'ca.pem',
                                               path='/app/')
        self.assertEqual(status, 200)
        self.assertIn(b'MySold TLS fixture', body)
        self.assertEqual(headers['Strict-Transport-Security'], 'max-age=31536000')
        self.assertEqual(self.request(http_port)[0], 200)
        self.assertEqual(self.request(http_port, headers={'X-Forwarded-Proto': 'https'})[1]
                         ['Strict-Transport-Security'], 'max-age=31536000')
        self.assertEqual(self.request(https_port, tls=True, cafile=self.base / 'ca.pem',
                                      path='/api/health')[0], 200)
        with self.assertRaises(ssl.SSLCertVerificationError):
            self.request(https_port, tls=True)
        with self.assertRaises(ssl.SSLCertVerificationError):
            self.request(https_port, tls=True, cafile=self.base / 'ca.pem', hostname='wrong.test')
        self.assertNotEqual(self.run_command([DOCKER, 'exec', container, 'id', '-u']).stdout.strip(), '0')
        self.run_command([DOCKER, 'exec', container, 'sh', '-c',
                          'test -r /etc/nginx/mysold-certs/privkey.pem && '
                          '! touch /etc/nginx/mysold-certs/.write-probe'])

    def test_tls_missing_or_mismatched_certificates_fail_closed(self):
        missing = self.base / 'missing'
        missing.mkdir()
        mismatch = self.base / 'mismatch'
        mismatch.mkdir(mode=0o750)
        mismatch.chmod(0o750)
        shutil.copy(self.certs / 'fullchain.pem', mismatch / 'fullchain.pem')
        shutil.copy(self.renewed / 'privkey.pem', mismatch / 'privkey.pem')
        for directory in (missing, mismatch):
            container = self.start_web(directory.name, directory)
            for _ in range(60):
                state = json.loads(self.run_command([DOCKER, 'inspect', container]).stdout)[0]['State']
                if state['Status'] == 'exited':
                    break
                time.sleep(.1)
            self.assertEqual(state['Status'], 'exited')
            self.assertNotEqual(state['ExitCode'], 0)

    def test_certificate_renewal_is_loaded_after_validation_and_reload(self):
        rotation = self.base / 'rotation'
        shutil.copytree(self.certs, rotation)
        container = self.start_web('rotation', rotation)
        self.wait_http(container)
        port = self.port(container, 8443)
        self.assertEqual(self.request(port, tls=True, cafile=self.base / 'ca.pem')[3]['serialNumber'], '01')
        for name in ('fullchain.pem', 'privkey.pem'):
            shutil.copyfile(self.renewed / name, rotation / name)
        self.run_command([DOCKER, 'exec', container, 'nginx', '-t'])
        self.run_command([DOCKER, 'exec', container, 'nginx', '-s', 'reload'])
        for _ in range(50):
            serial = self.request(port, tls=True, cafile=self.base / 'ca.pem')[3]['serialNumber']
            if serial == '02':
                break
            time.sleep(.1)
        self.assertEqual(serial, '02')

    def test_compose_tls_is_opt_in_read_only_and_requires_explicit_permissions(self):
        env = {k: v for k, v in os.environ.items() if not k.startswith('COMPOSE_')}
        env.update(POSTGRES_PASSWORD='test-only-configuration', TLS_CERT_GID='',
                   TLS_CERTS_DIR=str(self.certs), WEB_PORT='28085', WEB_HTTPS_PORT='28443',
                   WEB_BIND_ADDRESS='0.0.0.0', WEB_HTTPS_BIND_ADDRESS='0.0.0.0')
        command = [DOCKER, 'compose', '--env-file', str(ROOT / '.env.example'), '-f', str(ROOT / 'compose.yaml')]
        plain = json.loads(self.run_command([*command, 'config', '--format', 'json'], env=env).stdout)
        self.assertEqual(len(plain['services']['web']['ports']), 1)
        env['WEB_BIND_ADDRESS'] = ''
        legacy = json.loads(self.run_command([*command, 'config', '--format', 'json'], env=env).stdout)
        self.assertFalse(legacy['services']['web']['ports'][0].get('host_ip'))
        env['WEB_BIND_ADDRESS'] = '0.0.0.0'
        enabled = [*command, '-f', str(ROOT / 'compose.https.yaml')]
        self.assertNotEqual(self.run_command([*enabled, 'config', '--quiet'], env=env, check=False).returncode, 0)
        env['TLS_CERT_GID'] = self.gid
        secure = json.loads(self.run_command([*enabled, 'config', '--format', 'json'], env=env).stdout)
        web = secure['services']['web']
        self.assertEqual({p['target'] for p in web['ports']}, {8080, 8443})
        self.assertIn(self.gid, web['group_add'])
        for mount in web['volumes']:
            self.assertTrue(mount['read_only'])
            self.assertFalse(mount['bind']['create_host_path'])
        self.assertNotIn('user', web)
        env['WEB_BIND_ADDRESS'] = '127.0.0.1'
        local = json.loads(self.run_command([*enabled, 'config', '--format', 'json'], env=env).stdout)
        self.assertEqual(next(p for p in local['services']['web']['ports'] if p['target'] == 8080)['host_ip'], '127.0.0.1')
        env['COMPOSE_FILE'] = os.pathsep.join([str(ROOT / 'compose.yaml'), str(ROOT / 'compose.https.yaml')])
        env['COMPOSE_PATH_SEPARATOR'] = os.pathsep
        automatic = json.loads(self.run_command([DOCKER, 'compose', '--env-file', str(ROOT / '.env.example'),
                                                'config', '--format', 'json'], env=env).stdout)
        self.assertEqual({p['target'] for p in automatic['services']['web']['ports']}, {8080, 8443})


if __name__ == '__main__':
    unittest.main()

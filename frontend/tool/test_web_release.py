import hashlib
import io
import json
from pathlib import Path
import shutil
import tarfile
import tempfile
import unittest
from unittest.mock import patch
import urllib.error

import web_release as release


class WebReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.root = self.base / 'source'
        for name in release.INPUTS:
            path = self.root / name
            if name in ('lib', 'assets', 'web'):
                path.mkdir(parents=True)
                (path / 'example.txt').write_text('example\n')
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('example\n')
        self.web = self.base / 'compiled'
        self.web.mkdir()
        self.version = {'build': '2026.10.24.2017', 'contentHash': 'a' * 64}
        stamp = self.version['build'] + '-' + self.version['contentHash']
        for name in release.REQUIRED:
            path = self.web / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('public file\n')
        (self.web / 'version.json').write_text(json.dumps(self.version))
        (self.web / 'sw.js').write_text(f"const BUILD = '{stamp}';")
        (self.web / 'pwa_updates.js').write_text(f"const LOCAL_BUILD = '{self.version['build']}';")
        (self.web / 'flutter_bootstrap.js').write_text('main.dart.js?mysold_build=' + stamp)
        self.output = self.base / 'release'
        self.metadata = release.pack_release(self.web, self.output, 'b' * 40, self.root)

    def fake_download(self, url, destination, limit):
        name = url.rsplit('/', 1)[1]
        data = (self.output / name).read_bytes()
        destination.write_bytes(data)
        self.assertLessEqual(len(data), limit)
        return hashlib.sha256(data).hexdigest()

    def test_matching_release_installs_all_public_files(self):
        destination = self.base / 'installed'
        with patch.object(release, 'download', side_effect=self.fake_download):
            metadata = release.fetch_release('example/MySold', destination, self.root)
        self.assertEqual(metadata, self.metadata)
        for path in self.web.rglob('*'):
            if path.is_file():
                self.assertEqual(path.read_bytes(), (destination / path.relative_to(self.web)).read_bytes())
        self.assertFalse((destination / 'release.json').exists())
        self.assertFalse((destination / '.env').exists())

    def test_source_identity_is_stable_across_crlf_and_changes_with_new_code(self):
        original = release.source_hash(self.root)
        (self.root / 'lib/example.txt').write_bytes(b'example\r\n')
        self.assertEqual(release.source_hash(self.root), original)
        (self.root / 'lib/new.dart').write_text('new code')
        self.assertNotEqual(release.source_hash(self.root), original)

    def test_binary_assets_are_not_normalized(self):
        path = self.root / 'assets/image.png'
        path.write_bytes(b'\x00\r\n')
        original = release.source_hash(self.root)
        path.write_bytes(b'\x00\n')
        self.assertNotEqual(release.source_hash(self.root), original)

    def test_missing_or_changed_source_cannot_install_old_release(self):
        (self.root / 'lib/example.txt').write_text('changed source')
        destination = self.base / 'installed'
        with patch.object(release, 'download', side_effect=self.fake_download):
            with self.assertRaisesRegex(ValueError, 'does not match'):
                release.fetch_release('example/MySold', destination, self.root)
        self.assertFalse(destination.exists())

    def test_corrupt_download_is_rejected_before_installing(self):
        archive = self.output / release.ASSET
        archive.write_bytes(archive.read_bytes() + b'corruption')
        destination = self.base / 'installed'
        with patch.object(release, 'download', side_effect=self.fake_download):
            with self.assertRaisesRegex(ValueError, 'checksum mismatch'):
                release.fetch_release('example/MySold', destination, self.root)
        self.assertFalse(destination.exists())

    def test_missing_publication_reports_workflow_without_fallback(self):
        error = urllib.error.HTTPError('https://github.com/example', 404, 'Not Found', {}, None)
        with patch.object(release, 'download', side_effect=error):
            with self.assertRaisesRegex(ValueError, 'workflow at https://github.com/example/MySold/actions'):
                release.fetch_release('example/MySold', self.base / 'installed', self.root)

    def test_existing_installation_is_never_overwritten(self):
        destination = self.base / 'installed'
        destination.mkdir()
        (destination / 'keep.txt').write_text('keep')
        with self.assertRaisesRegex(ValueError, 'already exists'):
            release.fetch_release('example/MySold', destination, self.root)
        self.assertEqual((destination / 'keep.txt').read_text(), 'keep')

    def test_invalid_repository_and_insecure_redirect_are_rejected(self):
        for repository in ('https://example.test/repo', 'owner/repo?token=secret', 'owner/repo/extra'):
            with self.assertRaises(ValueError):
                release.fetch_release(repository, self.base / 'installed', self.root)
        with self.assertRaisesRegex(ValueError, 'insecure'):
            release.HttpsRedirects().redirect_request(None, None, 302, '', {}, 'http://example.test/file')

    def bad_archive(self, name, kind=tarfile.REGTYPE, content=b'bad', metadata=None):
        archive = self.base / 'bad.tar.gz'
        with tarfile.open(archive, 'w:gz') as tar:
            data = json.dumps(self.metadata if metadata is None else metadata).encode()
            header = tarfile.TarInfo('release.json')
            header.size = len(data)
            tar.addfile(header, io.BytesIO(data))
            header = tarfile.TarInfo(name)
            header.type, header.linkname = kind, '/outside'
            header.size = len(content) if kind == tarfile.REGTYPE else 0
            tar.addfile(header, io.BytesIO(content) if header.size else None)
        return archive

    def test_paths_links_devices_and_invalid_metadata_cannot_escape(self):
        for index, (name, kind) in enumerate([
            ('../outside', tarfile.REGTYPE), ('/outside', tarfile.REGTYPE),
            ('web/../../outside', tarfile.REGTYPE), ('web/C:/outside', tarfile.REGTYPE),
            ('web/..\\outside', tarfile.REGTYPE), ('web/link', tarfile.SYMTYPE),
            ('web/link', tarfile.LNKTYPE), ('web/device', tarfile.CHRTYPE),
            ('outside', tarfile.REGTYPE),
        ]):
            with self.subTest(name=name, kind=kind):
                with self.assertRaises(ValueError):
                    release.unpack_release(self.bad_archive(name, kind), self.base / f'bad-{index}', self.metadata['sourceHash'])
        with self.assertRaises(ValueError):
            release.unpack_release(self.bad_archive('web/file', metadata=[]), self.base / 'bad-json', self.metadata['sourceHash'])
        self.assertFalse((self.base / 'outside').exists())

    def test_unpacked_size_is_bounded(self):
        with patch.object(release, 'MAX_UNPACKED', 1024):
            with self.assertRaisesRegex(ValueError, 'size limit'):
                release.unpack_release(self.bad_archive('web/large', content=b'x' * 2048), self.base / 'large', self.metadata['sourceHash'])

    def test_pwa_worker_client_and_manifest_must_agree(self):
        (self.web / 'sw.js').write_text("const BUILD = '__MYSOLD_BUILD_ID__';")
        with self.assertRaisesRegex(ValueError, 'inconsistent'):
            release.pack_release(self.web, self.output, 'b' * 40, self.root)


if __name__ == '__main__':
    unittest.main()

"""Public Web releases keyed by the exact Flutter build inputs."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import sys
import tarfile
import tempfile
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
INPUTS = ('lib', 'assets', 'web', 'pubspec.yaml', 'pubspec.lock',
          'Dockerfile.source', 'tool/stamp_web_build.dart', 'tool/web_release.py')
TEXT_SUFFIXES = {'.dart', '.js', '.html', '.json', '.yaml', '.lock', '.md', '.txt', '.py', '.source'}
ASSET = 'mysold-web.tar.gz'
MAX_ARCHIVE = 150 * 1024 * 1024
MAX_UNPACKED = 300 * 1024 * 1024
REQUIRED = ('index.html', 'main.dart.js', 'flutter_bootstrap.js', 'version.json',
            'pwa_updates.js', 'sw.js', 'canvaskit/canvaskit.wasm')


def source_hash(root=ROOT):
    files = []
    for name in INPUTS:
        path = root / name
        if not path.exists():
            raise ValueError(f'Missing build input: {name}')
        if path.is_dir():
            files.extend(p for p in path.rglob('*') if p.is_file())
        else:
            files.append(path)
    digest = hashlib.sha256(b'mysold-web-release-v1\n')
    for path in sorted(files, key=lambda p: p.relative_to(root).as_posix()):
        if path.is_symlink():
            raise ValueError('Build inputs must not be symbolic links')
        data = path.read_bytes()
        if path.suffix in TEXT_SUFFIXES:
            data = data.replace(b'\r\n', b'\n')
        digest.update(path.relative_to(root).as_posix().encode() + b'\0')
        digest.update(hashlib.sha256(data).digest())
    return digest.hexdigest()


def validate_web(web):
    for name in REQUIRED:
        if not (web / name).is_file() or not (web / name).stat().st_size:
            raise ValueError(f'Missing Web release file: {name}')
    version = json.loads((web / 'version.json').read_text(encoding='utf-8'))
    build, content = version.get('build', ''), version.get('contentHash', '')
    if not re.fullmatch(r'\d{4}\.\d{2}\.\d{2}\.\d{4}', build) or not re.fullmatch('[a-f0-9]{64}', content):
        raise ValueError('Invalid PWA build manifest')
    checks = {'sw.js': f"const BUILD = '{build}-{content}';",
              'pwa_updates.js': f"const LOCAL_BUILD = '{build}';",
              'flutter_bootstrap.js': f'mysold_build={build}-{content}'}
    for name, expected in checks.items():
        if expected not in (web / name).read_text(encoding='utf-8'):
            raise ValueError('Unstamped or inconsistent PWA build: ' + name)
    return version


def pack_release(web, output, commit, root=ROOT):
    if not re.fullmatch('[a-f0-9]{40}', commit):
        raise ValueError('Expected a full Git commit SHA')
    version = validate_web(web)
    metadata = {'schema': 1, 'sourceHash': source_hash(root), 'commit': commit, **version}
    output.mkdir(parents=True, exist_ok=True)
    archive = output / ASSET
    with tarfile.open(archive, 'w:gz') as tar:
        data = json.dumps(metadata, sort_keys=True).encode()
        info = tarfile.TarInfo('release.json')
        info.size, info.mode = len(data), 0o644
        tar.addfile(info, io.BytesIO(data))
        for path in sorted(web.rglob('*')):
            if path.is_symlink() or not (path.is_dir() or path.is_file()):
                raise ValueError('Only regular Web files can be released')
            if path.is_file():
                tar.add(path, arcname='web/' + path.relative_to(web).as_posix(), recursive=False)
    with archive.open('rb') as stream:
        digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    (output / (ASSET + '.sha256')).write_text(f'{digest}  {ASSET}\n', encoding='utf-8')
    return metadata


class HttpsRedirects(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if urllib.parse.urlsplit(newurl).scheme != 'https':
            raise ValueError('Refusing an insecure release redirect')
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def download(url, destination, limit):
    request = urllib.request.Request(url, headers={'User-Agent': 'MySold-Web-Installer/1'})
    digest, total = hashlib.sha256(), 0
    with urllib.request.build_opener(HttpsRedirects()).open(request, timeout=45) as response, destination.open('wb') as target:
        while chunk := response.read(1024 * 1024):
            total += len(chunk)
            if total > limit:
                raise ValueError('Release download exceeds the size limit')
            digest.update(chunk)
            target.write(chunk)
    return digest.hexdigest()


def unpack_release(archive, destination, expected_source):
    destination.mkdir()
    total, names, metadata = 0, set(), None
    with tarfile.open(archive, 'r|gz') as tar:
        for index, member in enumerate(tar):
            name = PurePosixPath(member.name)
            if index > 10000 or name.is_absolute() or '..' in name.parts or '\\' in member.name or ':' in member.name:
                raise ValueError('Unsafe release archive path')
            if not member.isfile() or str(name).casefold() in names:
                raise ValueError('Release contains a link, special file or duplicate path')
            names.add(str(name).casefold())
            total += member.size
            if member.size < 0 or total > MAX_UNPACKED:
                raise ValueError('Unpacked release exceeds the size limit')
            stream = tar.extractfile(member)
            if index == 0:
                if str(name) != 'release.json' or member.size > 16384:
                    raise ValueError('Missing release metadata')
                metadata = json.loads(stream.read())
                if not isinstance(metadata, dict) or metadata.get('schema') != 1 or metadata.get('sourceHash') != expected_source:
                    raise ValueError('Release does not match the checked-out sources')
                continue
            if len(name.parts) < 2 or name.parts[0] != 'web':
                raise ValueError('Unexpected file outside the public Web directory')
            target = destination.joinpath(*name.parts[1:])
            target.parent.mkdir(parents=True, exist_ok=True)
            with target.open('xb') as output:
                shutil.copyfileobj(stream, output, length=1024 * 1024)
            target.chmod(0o644)
    if metadata is None:
        raise ValueError('Empty release archive')
    version = validate_web(destination)
    if any(metadata.get(key) != version[key] for key in ('build', 'contentHash')):
        raise ValueError('Release metadata disagrees with the PWA build')
    return metadata


def fetch_release(repository, destination, root=ROOT):
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repository):
        raise ValueError('Expected a public GitHub repository in OWNER/REPO format')
    if destination.exists():
        raise ValueError('Release destination already exists')
    source = source_hash(root)
    base = f'https://github.com/{repository}/releases/download/web-{source}/'
    print(f'Fetching Web release matching sources {source}', flush=True)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='mysold-release-', dir=destination.parent) as temporary:
        temporary = Path(temporary)
        checksum, archive = temporary / 'checksum', temporary / ASSET
        try:
            download(base + ASSET + '.sha256', checksum, 512)
            expected = re.fullmatch(r'([a-f0-9]{64})  mysold-web\.tar\.gz\n?', checksum.read_text(encoding='utf-8'))
            if expected is None:
                raise ValueError('Invalid release checksum file')
            if download(base + ASSET, archive, MAX_ARCHIVE) != expected[1]:
                raise ValueError('Web release checksum mismatch')
        except urllib.error.HTTPError as error:
            if error.code == 404:
                raise ValueError(f'The Web release for these sources is not published yet. '
                                 f'Wait for the Web release workflow at https://github.com/{repository}/actions '
                                 'and retry docker compose up -d --build. '
                                 'Developers can use compose.source.yaml to compile locally.') from error
            raise
        site = temporary / 'site'
        metadata = unpack_release(archive, site, source)
        os.replace(site, destination)
    print('Installed matching PWA build ' + metadata['build'])
    return metadata


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('source-hash')
    pack = commands.add_parser('pack')
    pack.add_argument('--web', type=Path, required=True)
    pack.add_argument('--output', type=Path, required=True)
    pack.add_argument('--commit', required=True)
    fetch = commands.add_parser('fetch')
    fetch.add_argument('--repository', required=True)
    fetch.add_argument('--destination', type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.command == 'source-hash':
            print(source_hash(args.root))
        elif args.command == 'pack':
            print(json.dumps(pack_release(args.web, args.output, args.commit, args.root)))
        else:
            fetch_release(args.repository, args.destination, args.root)
    except (OSError, ValueError, KeyError, tarfile.TarError) as error:
        print('MySold Web release: ' + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())

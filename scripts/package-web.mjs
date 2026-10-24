import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {execFileSync} from 'node:child_process';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
try {
  const web = path.join(root, 'frontend', 'build', 'web');
  const {build, contentHash} = JSON.parse(fs.readFileSync(path.join(web, 'version.json'), 'utf8'));
  if (!/^\d{4}\.\d{2}\.\d{2}\.\d{4}$/.test(build) || !/^[a-f0-9]{64}$/.test(contentHash)) {
    throw new Error('Numéro de build ou condensat invalide.');
  }
  const worker = fs.readFileSync(path.join(web, 'sw.js'), 'utf8');
  const client = fs.readFileSync(path.join(web, 'pwa_updates.js'), 'utf8');
  if (!worker.includes(`const BUILD = '${build}-${contentHash}';`) || !client.includes(`const LOCAL_BUILD = '${build}';`)) {
    throw new Error('Build PWA non estampillé ou incohérent : exécuter dart run tool/stamp_web_build.dart.');
  }
  for (const name of ['main.dart.js', 'index.html', 'flutter_bootstrap.js']) {
    if (!fs.statSync(path.join(web, name)).size) throw new Error(`Fichier manquant ou vide : ${name}`);
  }
  const dist = path.join(root, 'dist');
  fs.mkdirSync(dist, {recursive: true});
  const archive = path.join(dist, `mysold-web-${build}.tar.gz`);
  execFileSync('tar', ['-czf', archive, '-C', root, 'frontend/build/web',
    'compose.prebuilt.yaml', 'frontend/Dockerfile.prebuilt', 'frontend/Dockerfile.prebuilt.dockerignore'], {stdio: 'inherit'});
  console.log(archive);
} catch (error) {
  console.error('Archive Web non créée : ' + error.message);
  process.exitCode = 1;
}

import {randomBytes} from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
export function setupEnvironment(root) {
  const target = path.join(root, '.env');
  const content = fs.readFileSync(path.join(root, '.env.example'), 'utf8')
    .replace('REPLACE_WITH_A_RANDOM_PASSWORD', randomBytes(32).toString('hex'));
  try {
    fs.writeFileSync(target, content, {flag: 'wx', mode: 0o600});
    return '.env créé avec un mot de passe de base aléatoire.';
  } catch (error) {
    if (error.code !== 'EEXIST') throw error;
  }
  // Never rotate an existing database password: changing .env does not change
  // the password of the PostgreSQL role in an initialized persistent volume.
  const existing = fs.readFileSync(target, 'utf8');
  const assignment = existing.match(/^[ \t]*(?:export[ \t]+)?POSTGRES_PASSWORD[ \t]*=[ \t]*(.*)$/m);
  let password = assignment?.[1].trim() ?? '';
  if (password.startsWith('"') || password.startsWith("'")) {
    const quote = password[0];
    const end = password.indexOf(quote, 1);
    password = end < 0 ? '' : password.slice(1, end);
  } else {
    password = password.replace(/\s+#.*$/, '').trim();
  }
  if (!password || password === 'REPLACE_WITH_A_RANDOM_PASSWORD' || password.startsWith('#')) {
    throw new Error('.env existe mais POSTGRES_PASSWORD est absent, vide ou non configuré. '
      + 'Restaurez le secret de votre installation existante ; pour une nouvelle installation uniquement, '
      + 'renseignez un secret aléatoire fort. Aucune configuration n’a été modifiée.');
  }
  return '.env déjà présent et POSTGRES_PASSWORD renseigné ; configuration conservée.';
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
    console.log(setupEnvironment(root));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}

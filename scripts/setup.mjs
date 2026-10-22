import {randomBytes} from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const target = path.join(root, '.env');
const content = fs.readFileSync(path.join(root, '.env.example'), 'utf8')
  .replace('REPLACE_WITH_A_RANDOM_PASSWORD', randomBytes(32).toString('hex'));
try {
  fs.writeFileSync(target, content, {flag: 'wx', mode: 0o600});
  console.log('.env created with a random database password.');
} catch (error) {
  if (error.code !== 'EEXIST') throw error;
  console.log('.env already exists; keeping your configuration.');
}

import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {setupEnvironment} from './setup.mjs';

function fixture(t, existing) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'mysold-setup-'));
  t.after(() => fs.rmSync(root, {recursive: true, force: true}));
  fs.writeFileSync(path.join(root, '.env.example'), 'POSTGRES_PASSWORD=REPLACE_WITH_A_RANDOM_PASSWORD\nWEB_PORT=28085\n');
  if (existing !== undefined) fs.writeFileSync(path.join(root, '.env'), existing);
  return root;
}

test('New installations get a random secret; rerunning preserves the exact configuration', t => {
  const root = fixture(t);
  setupEnvironment(root);
  const initial = fs.readFileSync(path.join(root, '.env'), 'utf8');
  assert.match(initial, /^POSTGRES_PASSWORD=[0-9a-f]{64}\n/);
  setupEnvironment(root);
  assert.equal(fs.readFileSync(path.join(root, '.env'), 'utf8'), initial);
  const second = fixture(t);
  setupEnvironment(second);
  assert.notEqual(fs.readFileSync(path.join(second, '.env'), 'utf8'), initial);
});

for (const value of ['', 'WEB_PORT=28085\n', 'POSTGRES_PASSWORD=\n', 'POSTGRES_PASSWORD=\nWEB_PORT=28085\n', 'POSTGRES_PASSWORD= \r\nWEB_PORT=28085\r\n', 'POSTGRES_PASSWORD=""\n', "POSTGRES_PASSWORD='' # empty\n", 'POSTGRES_PASSWORD= # empty\n', 'POSTGRES_PASSWORD=REPLACE_WITH_A_RANDOM_PASSWORD\n']) {
  test('Incomplete existing environment is rejected without changing or disclosing it: ' + JSON.stringify(value), t => {
    const root = fixture(t, value);
    assert.throws(() => setupEnvironment(root), /Aucune configuration n’a été modifiée/);
    assert.equal(fs.readFileSync(path.join(root, '.env'), 'utf8'), value);
  });
}

test('Existing quoted secrets and other settings are kept verbatim and not printed', t => {
  const contents = "POSTGRES_PASSWORD='existing secret # stays'\nAPP_ORIGIN=https://example.test\n";
  const root = fixture(t, contents);
  const message = setupEnvironment(root);
  assert.equal(fs.readFileSync(path.join(root, '.env'), 'utf8'), contents);
  assert.ok(!message.includes('existing secret'));
});

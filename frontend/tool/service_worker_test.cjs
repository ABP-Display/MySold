const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { runInNewContext } = require('node:vm');
const source = readFileSync(require('node:path').join(__dirname, '../web/sw.js'), 'utf8');

function fixture() {
  const listeners = {}, cached = [], deleted = [];
  runInNewContext(source, {
    URL, Promise,
    self: { location: { origin: 'https://mysold.test' },
      addEventListener: (name, callback) => { listeners[name] = callback; },
      clients: { claim: async () => {} },
    },
    fetch: async () => ({ status: 200 }),
    caches: {
      open: async () => ({ addAll: async paths => cached.push(...paths) }),
      keys: async () => ['other-app', 'mysold-shell-old', 'flutter-app-cache'],
      delete: async key => { deleted.push(key); },
      match: async () => ({ status: 200 }),
    },
  });
  return { listeners, cached, deleted };
}

test('Only the Flutter application gets the offline navigation fallback', () => {
  const { listeners } = fixture();
  for (const path of ['/', '/index.html', '/?mysold_update=2026.11.21.1358',
    '/decouvrir/', '/conditions/', '/confidentialite/', '/cookies/', '/mentions-legales/',
    '/robots.txt', '/sitemap.xml', '/does-not-exist', '/api/auth/session', '/version.json']) {
    let intercepted = false;
    listeners.fetch({ request: { method: 'GET', mode: 'navigate', url: 'https://mysold.test' + path },
      respondWith: () => { intercepted = true; } });
    assert.equal(intercepted, ['/', '/index.html'].includes(new URL(path, 'https://mysold.test').pathname), path);
  }
});

test('No mutation, external URL or API response is cached', () => {
  const { listeners } = fixture();
  for (const [method, url] of [['POST', 'https://mysold.test/'],
    ['GET', 'https://other.test/'], ['GET', 'https://mysold.test/api/documents/get']]) {
    listeners.fetch({ request: { method, mode: 'navigate', url },
      respondWith: () => assert.fail('This response must not be intercepted') });
  }
});

test('Installation caches only the shell; activation preserves other applications', async () => {
  const { listeners, cached, deleted } = fixture();
  let task;
  listeners.install({ waitUntil: value => { task = value; } });
  await task;
  assert.deepEqual(cached, ['/', '/index.html', '/manifest.json', '/favicon.png']);
  listeners.activate({ waitUntil: value => { task = value; } });
  await task;
  assert.deepEqual(deleted.sort(), ['flutter-app-cache', 'mysold-shell-old']);
});

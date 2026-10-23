const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const CURRENT = '2026.10.23.2145';
const NEXT = '2026.10.23.2200';
const source = fs.readFileSync(path.join(__dirname, '../web/pwa_updates.js'), 'utf8')
  .replace('__MYSOLD_BUILD_VERSION__', CURRENT);

function browser({supported = true, online = true, version = CURRENT, waiting = null, update, fetchError = false} = {}) {
  let reloads = 0;
  let fetches = 0;
  let updates = 0;
  const serviceWorker = new EventTarget();
  const state = {version};
  const registration = {waiting, installing: null, update: async () => { updates++; if (update) await update(); }};
  serviceWorker.register = async (url, options) => {
    assert.equal(url, '/sw.js');
    assert.equal(options.updateViaCache, 'none');
    return registration;
  };
  const window = {isSecureContext: true, location: {reload: () => reloads++}};
  vm.runInNewContext(source, {
    window, navigator: supported ? {serviceWorker, onLine: online} : {onLine: online},
    setTimeout, clearTimeout, AbortController,
    fetch: async (url, options) => {
      fetches++;
      assert.equal(url, '/version.json');
      assert.equal(options.cache, 'no-store');
      if (fetchError) throw new Error('network');
      return {ok: true, json: async () => ({build: state.version})};
    },
  });
  return {window, registration, serviceWorker, state, reloads: () => reloads, fetches: () => fetches, updates: () => updates};
}

test('same build makes one uncached server check and reports latest', async () => {
  const state = browser();
  assert.equal(await state.window.mysoldCheckForUpdate(), 'latest');
  assert.equal(state.fetches(), 1);
  assert.equal(state.updates(), 0);
  assert.equal(state.window.mysoldBuildVersion, CURRENT);
  assert.equal(state.window.mysoldUpdateVersion, '');
});

test('unsupported and offline browsers do not request a version', async () => {
  for (const [options, expected] of [[{supported: false}, 'unsupported'], [{online: false}, 'offline']]) {
    const state = browser(options);
    assert.equal(await state.window.mysoldCheckForUpdate(), expected);
    assert.equal(state.fetches(), 0);
  }
});

test('different build is available but never activates or reloads without confirmation', async () => {
  const state = browser({version: NEXT, waiting: {postMessage() { assert.fail('Unexpected activation'); }}});
  assert.equal(await state.window.mysoldCheckForUpdate(), 'available');
  assert.equal(state.window.mysoldUpdateVersion, NEXT);
  assert.equal(state.window.mysoldBuildVersion, CURRENT);
  assert.equal(state.reloads(), 0);
});

test('check waits for installation to finish', async () => {
  const worker = new EventTarget();
  worker.state = 'installing';
  const state = browser({version: NEXT, update: async () => {
    state.registration.installing = worker;
    setImmediate(() => {
      worker.state = 'installed';
      state.registration.waiting = worker;
      worker.dispatchEvent(new Event('statechange'));
    });
  }});
  assert.equal(await state.window.mysoldCheckForUpdate(), 'available');
});

test('failed or invalid manifest does not report latest', async () => {
  assert.equal(await browser({fetchError: true}).window.mysoldCheckForUpdate(), 'error');
  assert.equal(await browser({version: '<html>'}).window.mysoldCheckForUpdate(), 'error');
});

test('failed installation reports error', async () => {
  const state = browser({version: NEXT});
  state.registration.installing = {state: 'redundant'};
  assert.equal(await state.window.mysoldCheckForUpdate(), 'error');
});

test('confirmed activation reloads once after controller changes', async () => {
  const state = browser({version: NEXT, waiting: {postMessage(message) {
    assert.equal(message.type, 'MYSOLD_SKIP_WAITING');
    state.serviceWorker.dispatchEvent(new Event('controllerchange'));
  }}});
  await state.window.mysoldCheckForUpdate();
  assert.equal(await state.window.mysoldApplyUpdate(), true);
  assert.equal(state.reloads(), 1);
  state.serviceWorker.dispatchEvent(new Event('controllerchange'));
  assert.equal(state.reloads(), 1);
});

test('different running build still offers reload when another tab already activated worker', async () => {
  const state = browser({version: NEXT});
  assert.equal(await state.window.mysoldCheckForUpdate(), 'available');
  assert.equal(await state.window.mysoldApplyUpdate(), true);
  assert.equal(state.reloads(), 1);
});

test('no update or no check cannot reload', async () => {
  const state = browser();
  assert.equal(await state.window.mysoldApplyUpdate(), false);
  await state.window.mysoldCheckForUpdate();
  assert.equal(await state.window.mysoldApplyUpdate(), false);
  assert.equal(state.reloads(), 0);
});

test('simultaneous startup and manual checks share one request', async () => {
  const state = browser();
  const results = await Promise.all([state.window.mysoldCheckForUpdate(), state.window.mysoldCheckForUpdate()]);
  assert.deepEqual(results, ['latest', 'latest']);
  assert.equal(state.fetches(), 1);
});

test('server returned to installed build before confirmation does not reload', async () => {
  const state = browser({version: NEXT});
  await state.window.mysoldCheckForUpdate();
  state.state.version = CURRENT;
  assert.equal(await state.window.mysoldApplyUpdate(), false);
  assert.equal(state.reloads(), 0);
});

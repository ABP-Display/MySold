const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../web/pwa_updates.js'), 'utf8');

function browser({supported = true, online = true, waiting = null, update} = {}) {
  let reloads = 0;
  const serviceWorker = new EventTarget();
  const registration = {waiting, installing: null, update: update || (async () => {})};
  serviceWorker.register = async (url, options) => {
    assert.equal(url, '/sw.js');
    assert.equal(options.updateViaCache, 'none');
    return registration;
  };
  const window = {isSecureContext: true, location: {reload: () => reloads++}};
  vm.runInNewContext(source, {
    window, navigator: supported ? {serviceWorker, onLine: online} : {onLine: online},
    setTimeout, clearTimeout,
  });
  return {window, registration, serviceWorker, reloads: () => reloads};
}

test('unsupported and offline browsers receive accurate states', async () => {
  assert.equal(await browser({supported: false}).window.mysoldCheckForUpdate(), 'unsupported');
  assert.equal(await browser({online: false}).window.mysoldCheckForUpdate(), 'offline');
});

test('no new worker reports latest', async () => {
  assert.equal(await browser().window.mysoldCheckForUpdate(), 'latest');
});

test('available update never activates or reloads without confirmation', async () => {
  const state = browser({waiting: {postMessage() { assert.fail('Unexpected activation'); }}});
  assert.equal(await state.window.mysoldCheckForUpdate(), 'available');
  assert.equal(state.reloads(), 0);
});

test('check waits for installation to finish', async () => {
  const worker = new EventTarget();
  worker.state = 'installing';
  const state = browser({update: async () => {
    state.registration.installing = worker;
    setImmediate(() => {
      worker.state = 'installed';
      state.registration.waiting = worker;
      worker.dispatchEvent(new Event('statechange'));
    });
  }});
  assert.equal(await state.window.mysoldCheckForUpdate(), 'available');
});

test('failed checks report error instead of claiming to be current', async () => {
  const state = browser({update: async () => { throw new Error('network'); }});
  assert.equal(await state.window.mysoldCheckForUpdate(), 'error');
});

test('failed installation does not report latest', async () => {
  const state = browser();
  state.registration.installing = {state: 'redundant'};
  assert.equal(await state.window.mysoldCheckForUpdate(), 'error');
});

test('confirmed activation reloads once after controller changes', async () => {
  const state = browser({waiting: {postMessage(message) {
    assert.equal(message.type, 'MYSOLD_SKIP_WAITING');
    state.serviceWorker.dispatchEvent(new Event('controllerchange'));
  }}});
  assert.equal(await state.window.mysoldApplyUpdate(), true);
  assert.equal(state.reloads(), 1);
  state.serviceWorker.dispatchEvent(new Event('controllerchange'));
  assert.equal(state.reloads(), 1);
});

test('no pending update does not reload', async () => {
  const state = browser();
  assert.equal(await state.window.mysoldApplyUpdate(), false);
  assert.equal(state.reloads(), 0);
});

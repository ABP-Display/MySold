const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { runInNewContext } = require('node:vm');
const source = readFileSync(require('node:path').join(__dirname, '../web/privacy_gesture.js'), 'utf8');
function setup(device = {}, secure = true) {
  const listeners = new Set();
  let now = 0;
  const window = {
    DeviceMotionEvent: device, isSecureContext: secure,
    addEventListener: (_, fn) => listeners.add(fn),
    removeEventListener: (_, fn) => listeners.delete(fn),
    setTimeout, clearTimeout,
  };
  runInNewContext(source, { window, performance: { now: () => now } });
  return { window, listeners, move: (x, time) => { now = time; for (const fn of [...listeners]) fn({ accelerationIncludingGravity: x }); } };
}
test('Unsupported, insecure and denied motion are unavailable', async () => {
  assert.equal(await setup(null).window.mysoldRequestMotionPermission(), false);
  assert.equal(await setup({}, false).window.mysoldRequestMotionPermission(), false);
  assert.equal(await setup({ requestPermission: async () => 'denied' }).window.mysoldRequestMotionPermission(), false);
});
test('Permission is requested only on explicit activation', async () => {
  let requests = 0;
  const env = setup({ requestPermission: async () => { requests++; return 'granted'; } });
  env.window.mysoldStartShake(() => {});
  assert.equal(requests, 0);
  assert.equal(await env.window.mysoldRequestMotionPermission(), true);
  assert.equal(requests, 1);
});
test('Sensor probe accepts real numeric data and cleans its listener', async () => {
  const env = setup();
  const permission = env.window.mysoldRequestMotionPermission();
  env.move({ x: null, y: null, z: null }, 0);
  assert.equal(env.listeners.size, 1);
  env.move({ x: 0, y: 0, z: 9.8 }, 1);
  assert.equal(await permission, true);
  assert.equal(env.listeners.size, 0);
});
test('Normal motion is ignored, shake is debounced, stopping removes callbacks', () => {
  const env = setup();
  let count = 0;
  env.window.mysoldStartShake(() => count++);
  env.move({ x: 0, y: 0, z: 9.8 }, 0);
  env.move({ x: null, y: null, z: null }, 20);
  env.move({ x: 24, y: 0, z: 0 }, 100);
  env.move({ x: 24, y: 0, z: 0 }, 200);
  env.move({ x: 24, y: 0, z: 0 }, 1400);
  assert.equal(count, 2);
  env.window.mysoldStartShake(() => count++);
  assert.equal(env.listeners.size, 1);
  env.window.mysoldStopShake();
  env.move({ x: 24, y: 0, z: 0 }, 3000);
  assert.equal(count, 2);
  assert.equal(env.listeners.size, 0);
});

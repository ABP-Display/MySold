const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { runInNewContext } = require('node:vm');
const source = readFileSync(require('node:path').join(__dirname, '../web/privacy_gesture.js'), 'utf8');
function setup(device = {}, secure = true) {
  const listeners = new Set();
  const visibilityListeners = new Set();
  let now = 0;
  const window = {
    DeviceMotionEvent: device, isSecureContext: secure,
    addEventListener: (_, fn) => listeners.add(fn),
    removeEventListener: (_, fn) => listeners.delete(fn),
    setTimeout, clearTimeout,
    document: {
      hidden: false,
      addEventListener: (_, fn) => visibilityListeners.add(fn),
      removeEventListener: (_, fn) => visibilityListeners.delete(fn),
    },
  };
  runInNewContext(source, { window, performance: { now: () => now } });
  return { window, listeners, visibilityListeners,
    visibility: hidden => {
      window.document.hidden = hidden;
      for (const fn of visibilityListeners) fn();
    },
    move: (x, time, acceleration) => { now = time; for (const fn of [...listeners]) fn({ accelerationIncludingGravity: x, acceleration }); } };
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
const portrait = {x:0, y:9.8, z:0};
const landscape = {x:9.8, y:0, z:0};
const reversed = {x:0, y:-9.8, z:0};
function hold(env, vector, start, duration=1000, acceleration) {
  for(let t=start; t<=start+duration; t+=50) env.move(vector,t,acceleration);
}

test('Small tilts, bumps and brief turns do not hide amounts', () => {
  const env = setup();
  let count = 0;
  env.window.mysoldStartShake(() => count++);
  env.move(portrait, 0);
  env.move({ x: null, y: null, z: null }, 20);
  hold(env, {x:4.9,y:8.49,z:0}, 50);
  hold(env, {x:24,y:0,z:0}, 1100);
  hold(env, landscape, 2200, 1000, {x:3,y:0,z:0});
  hold(env, portrait, 3250);
  hold(env, reversed, 4300, 100);
  hold(env, portrait, 4450);
  assert.equal(count, 0);
});

for (const [name, vector] of [['90 degrees', landscape], ['180 degrees', reversed]]) {
  test(`A deliberate ${name} turn hides once, returning rearms`, () => {
    const env = setup();
    let count = 0;
    env.window.mysoldStartShake(() => count++);
    hold(env, portrait, 0);
    hold(env, vector, 1050);
    assert.equal(count, 1);
    hold(env, vector, 2100, 2000);
    assert.equal(count, 1);
    hold(env, portrait, 4150);
    hold(env, vector, 5200);
    assert.equal(count, 2);
  });
}

test('Hidden pages, resumed sensors and stopping reset the reference', () => {
  const env = setup();
  let count = 0;
  env.window.mysoldStartShake(() => count++);
  hold(env, portrait, 0);
  env.visibility(true);
  hold(env, reversed, 1050);
  env.visibility(false);
  hold(env, reversed, 2100);
  assert.equal(count, 0);
  hold(env, portrait, 5000); // Long sensor gap: new reference, no surprise hide.
  assert.equal(count, 0);
  env.window.mysoldStartShake(() => count++);
  assert.equal(env.listeners.size, 1);
  assert.equal(env.visibilityListeners.size, 1);
  env.window.mysoldStopShake();
  hold(env, reversed, 7000);
  assert.equal(count, 0);
  assert.equal(env.listeners.size, 0);
  assert.equal(env.visibilityListeners.size, 0);
});

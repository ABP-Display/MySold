const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

test('The PWA explicitly selects full CanvasKit to avoid the deprecated Chromium text API', () => {
  const source = fs.readFileSync(path.join(__dirname, '../web/flutter_bootstrap.js'), 'utf8')
    .replace('{{flutter_js}}', '').replace('{{flutter_build_config}}', '');
  let loaded;
  const window = {};
  vm.runInNewContext(source, {_flutter: {loader: {load: options => {loaded = options;}}}, window});
  assert.equal(loaded.config.canvasKitVariant, 'full');
  assert.equal(loaded.config.canvasKitBaseUrl, '/canvaskit/');
  assert.equal(typeof window.mysoldNotify, 'function');
  assert.equal(typeof window.mysoldRequestNotifications, 'function');
});

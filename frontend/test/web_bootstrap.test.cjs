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
  assert.equal(loaded.config.fontFallbackBaseUrl, '/font-fallbacks/');
  assert.equal(typeof window.mysoldNotify, 'function');
  assert.equal(typeof window.mysoldRequestNotifications, 'function');
});

test('Engine fallback fonts are shipped locally with their licenses', () => {
  const directory = path.join(__dirname, '../web/font-fallbacks');
  for (const [family, file] of [
    ['NotoSans', 'notosans/v37/o-0mIpQlx3QUlC5A4PNB6Ryti20_6n1iPHjcz6L1SoM-jCpoiyD9A99Y41P6zHtY.woff2'],
    ['NotoSansSymbols', 'notosanssymbols/v43/rP2up3q65FkAtHfwd-eIS2brbDN6gxP34F9jRRCe4W3gfQ8gb_VFRkzrbQ.woff2'],
  ]) {
    const bytes = fs.readFileSync(path.join(directory, file));
    assert.equal(bytes.subarray(0, 4).toString(), 'wOF2');
    assert.equal(bytes.readUInt32BE(8), bytes.length);
    assert.match(fs.readFileSync(path.join(directory, `${family}-LICENSE.txt`), 'utf8'), /SIL OPEN FONT LICENSE/);
  }
});

test('The startup cover is removed only after Flutter paints its first frame', () => {
  const source = fs.readFileSync(path.join(__dirname, '../web/flutter_bootstrap.js'), 'utf8')
    .replace('{{flutter_js}}', '').replace('{{flutter_build_config}}', '');
  let remove = 0, firstFrame, options;
  vm.runInNewContext(source, {_flutter: {loader: {load() {}}},
    window: {addEventListener(name, fn, opts) {assert.equal(name, 'flutter-first-frame'); firstFrame=fn; options=opts;}},
    document: {getElementById(id) {assert.equal(id,'mysold-startup'); return {remove() {remove++;}};}}});
  assert.equal(remove,0); assert.equal(options.once,true); firstFrame(); assert.equal(remove,1);
});

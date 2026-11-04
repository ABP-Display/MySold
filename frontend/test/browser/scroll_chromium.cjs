// Build scroll_fixture.dart, then run with an isolated Chromium debug endpoint:
// node test/browser/scroll_chromium.cjs http://127.0.0.1:9235
const {createServer} = require('node:http');
const {readFile} = require('node:fs/promises');
const path = require('node:path');
const assert = require('node:assert/strict');
const {once} = require('node:events');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
const root = path.resolve(__dirname, '../../build/scroll-fixture');
const debug = process.argv[2] || 'http://127.0.0.1:9235';
const server = createServer(async (req, res) => {
  const name = new URL(req.url, 'http://localhost').pathname;
  const file = path.resolve(root, '.' + (name === '/' ? '/index.html' : name));
  if (!file.startsWith(root + path.sep)) return res.writeHead(403).end();
  try {
    const bytes = await readFile(file);
    res.setHeader('Content-Type', ({'.js':'text/javascript', '.wasm':'application/wasm',
      '.html':'text/html', '.json':'application/json'})[path.extname(file)] || 'application/octet-stream');
    res.end(bytes);
  } catch { res.writeHead(404).end(); }
});

async function measure(origin, mode, width=390) {
  const target = await (await fetch(debug + '/json/new?about:blank', {method:'PUT'})).json();
  const socket = new WebSocket(target.webSocketDebuggerUrl);
  await once(socket, 'open');
  let id = 0;
  const pending = new Map();
  socket.addEventListener('message', event => {
    const message = JSON.parse(event.data);
    if (!message.id) return;
    const task = pending.get(message.id);
    pending.delete(message.id);
    if (message.error) task.reject(new Error(JSON.stringify(message.error)));
    else task.resolve(message.result);
  });
  const send = (method, params={}) => new Promise((resolve,reject) => {
    const key = ++id;
    pending.set(key, {resolve,reject});
    socket.send(JSON.stringify({id:key, method, params}));
  });
  const evaluate = async expression => (await send('Runtime.evaluate', {
    expression, returnByValue:true,
  })).result.value;
  const touch = (type, x=195, y=140) => send('Input.dispatchTouchEvent', {
    type, touchPoints:type === 'touchEnd' ? [] : [{x,y,id:1}],
  });
  try {
    await send('Emulation.setDeviceMetricsOverride', {width,height:844,deviceScaleFactor:1,mobile:width<600});
    await send('Emulation.setTouchEmulationEnabled', {enabled:true,maxTouchPoints:1});
    await send('Page.navigate', {url: origin + '/?semantics=' + mode});
    let ready = false;
    for(let i=0; i<200; i++) {
      ready = await evaluate('document.body?.dataset.fixtureReady === "true"');
      if(ready) break;
      await delay(100);
    }
    assert.ok(ready, 'Fixture did not load');
    if (mode === 'workspace') {
      assert.equal(await evaluate('document.body.dataset.pageNotifications'), '1,1,1,1');
      assert.equal(Number(await evaluate('document.body.dataset.selectedTab')), 0);
      for (const index of [1,2,3,0]) {
        await evaluate(`window.dispatchEvent(new CustomEvent('mysold-fixture-tab', {detail:${index}}))`);
        await delay(450);
        assert.equal(Number(await evaluate('document.body.dataset.selectedTab')), index);
      }
      assert.equal(await evaluate('document.body.dataset.pageNotifications'), '1,1,1,1');
      return {mode, width, preparedPages:4, initialDataNotifications:'1,1,1,1', returnedToMonth:true};
    }
    const coordinates = await evaluate('Object.assign({}, document.body.dataset)');
    await touch('touchStart',Number(coordinates.emailX),Number(coordinates.emailY));
    await touch('touchEnd');
    await delay(300);
    const autofill = await evaluate(`(() => {
      function inputs(root) {
        return [...root.querySelectorAll('input'),
          ...[...root.querySelectorAll('*')].filter(e => e.shadowRoot).flatMap(e => inputs(e.shadowRoot))];
      }
      const fields = inputs(document);
      const username = fields.find(e => e.autocomplete === 'username' && e.form);
      const password = fields.find(e => e.autocomplete === 'current-password' && e.form);
      if (!username || !password || username.form !== password.form) return {
        fields: fields.map(e => ({autocomplete:e.autocomplete, form:!!e.form, type:e.type,
          parent:e.parentElement?.tagName, closest:!!e.closest('form'), attrs:e.getAttributeNames()})),
        active: document.activeElement?.tagName,
      };
      username.value = 'fixture@example.test';
      username.dispatchEvent(new Event('input', {bubbles:true}));
      password.value = 'Fixture-only-123!';
      password.dispatchEvent(new Event('input', {bubbles:true}));
      return true;
    })()`);
    assert.equal(autofill, true, 'Native form: ' + JSON.stringify(autofill));
    await delay(100);
    assert.equal(await evaluate('document.body.dataset.nativeFilled'), 'true', 'Native autofill must update Flutter controllers');
    await touch('touchStart',Number(coordinates.continueX),Number(coordinates.continueY));
    await delay(30);
    await touch('touchEnd');
    await delay(700);
    const tappables = await evaluate("document.querySelectorAll('[flt-tappable]').length");
    await evaluate(`(() => {
      window.probeThresholdTime = null;
      window.addEventListener('pointerdown', () => window.probeStart = performance.now(), {once:true,capture:true});
      window.addEventListener('pointermove', event => {
        if (window.probeThresholdTime === null && Math.abs(event.clientY - 140) > 8)
          window.probeThresholdTime = performance.now();
      }, {capture:true});
    })()`);
    await touch('touchStart');
    let initial = null;
    for(let step=1; step<=16; step++) {
      await delay(16);
      await touch('touchMove',195,140-step*5);
      const offset = await evaluate('Number(document.body.dataset.scrollOffset || 0)');
      if(offset>0 && initial === null) initial = await evaluate('Number(document.body.dataset.scrollTime) - window.probeStart');
    }
    await delay(200); // End the diagnostic drag without starting a fling.
    await touch('touchEnd');
    await delay(300);
    const clicks = await evaluate('Number(document.body.dataset.clicks || 0)');
    assert.equal(clicks, 0, 'A scroll must not activate the button');
    assert.notEqual(initial, null, 'The gesture must scroll');
    const thresholdTime = await evaluate('window.probeThresholdTime - window.probeStart');
    const offset = await evaluate('Number(document.body.dataset.scrollOffset || 0)');
    await touch('touchStart',195,140-offset);
    await delay(30);
    await touch('touchEnd');
    await delay(250);
    const tapClicks = await evaluate('Number(document.body.dataset.clicks || 0)');
    assert.equal(tapClicks, 1, 'A released tap must activate exactly once');
    return {mode, tappables, firstScrollMs:Math.round(initial),
      afterThresholdMs:Math.round(initial - thresholdTime), clicks, tapClicks, nativeAutofill:autofill};
  } finally {
    socket.close();
    await fetch(debug + '/json/close/' + target.id);
  }
}

(async () => {
  server.listen(0,'127.0.0.1');
  await once(server,'listening');
  const origin = 'http://127.0.0.1:' + server.address().port;
  try {
    const results = [];
    for(const mode of ['normal','forced']) results.push(await measure(origin,mode));
    for(const width of [390,1280]) results.push(await measure(origin,'workspace',width));
    console.log(JSON.stringify(results,null,2));
    assert.equal(results[0].tappables, 0, 'Autofill must not leave global semantics enabled');
    assert.ok(results[0].afterThresholdMs < 160, 'Ordinary touch scrolling still waits for the semantics debounce');
  } finally { server.closeAllConnections(); server.close(); }
})().catch(error => { console.error(error); process.exitCode=1; });

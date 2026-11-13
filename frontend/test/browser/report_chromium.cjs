// Build report_fixture.dart to build/report-fixture, then run against isolated Edge.
const {createServer} = require('node:http');
const {readFile, writeFile, mkdir} = require('node:fs/promises');
const path = require('node:path');
const {once} = require('node:events');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../../build/report-fixture');
const output = path.resolve(__dirname, '../../../test-results');
const debug = process.argv[2] || 'http://127.0.0.1:9235';
const language = process.env.FIXTURE_LANG || 'fr';
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

(async () => {
  await mkdir(output, {recursive:true});
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  let socket, target;
  try {
    target = await (await fetch(debug + '/json/new?about:blank', {method:'PUT'})).json();
    socket = new WebSocket(target.webSocketDebuggerUrl);
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
      const timeout = setTimeout(() => { pending.delete(key); reject(new Error(`${method} timed out`)); }, 15000);
      pending.set(key, {
        resolve: value => { clearTimeout(timeout); resolve(value); },
        reject: error => { clearTimeout(timeout); reject(error); },
      });
      socket.send(JSON.stringify({id:key, method, params}));
    });
    const evaluate = async expression => (await send('Runtime.evaluate', {
      expression, returnByValue:true,
    })).result.value;
    await send('Emulation.setDeviceMetricsOverride', {width:390,height:844,deviceScaleFactor:1,mobile:true});
    const expectError = process.env.REPORT_EXPECT_ERROR === '1';
    await send('Page.navigate', {url:`http://127.0.0.1:${server.address().port}/?lang=${encodeURIComponent(language)}${expectError ? '&scenario=january' : ''}`});
    let ready = false;
    for (let i=0; i<600; i++) {
      const error = await evaluate('document.body?.dataset.reportError');
      if (expectError && error) {
        assert.match(error, /more than 20 pages|won.t fit/);
        console.log('Reproduced January pagination failure: ' + error.split('\n')[0]);
        return;
      }
      assert.ok(!error, error);
      ready = await evaluate('document.body?.dataset.reportReady === "true"');
      if (ready) break;
      await new Promise(resolve => setTimeout(resolve,100));
    }
    assert.ok(ready, 'Report fixture timed out');
    assert.ok(!expectError, 'Expected the legacy January export to fail');
    for (const scenario of ['month','year','empty','single','negative','january','february','long']) {
      const data = await evaluate(`document.body.dataset.pdf${scenario}`);
      const bytes = Buffer.from(data, 'base64');
      assert.equal(bytes.subarray(0,5).toString(), '%PDF-');
      assert.ok(bytes.length > 5000);
      await writeFile(path.join(output, `report-${language}-${scenario}.pdf`), bytes);
      console.log(`${scenario}: ${bytes.length} bytes`);
    }
    for (const width of [390,1280]) {
      await send('Emulation.setDeviceMetricsOverride', {width,height:900,deviceScaleFactor:1,mobile:width<760});
      await new Promise(resolve => setTimeout(resolve,300));
      const shot = await send('Page.captureScreenshot', {format:'png'});
      await writeFile(path.join(output, `report-picker-${width}.png`), Buffer.from(shot.data,'base64'));
    }
  } finally {
    socket?.close();
    if (target) await fetch(debug + '/json/close/' + target.id);
    server.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });

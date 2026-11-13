// Build page_tabs_fixture.dart to build/page-tabs-fixture, then use isolated Edge.
const {createServer} = require('node:http');
const {readFile, writeFile, mkdir} = require('node:fs/promises');
const path = require('node:path');
const {once} = require('node:events');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../../build/page-tabs-fixture');
const output = path.resolve(__dirname, '../../../test-results');
const debug = process.argv[2] || 'http://127.0.0.1:9235';
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
const server = createServer(async (req, res) => {
  const name = new URL(req.url, 'http://localhost').pathname;
  if (name === '/api/analysis/annual') {
    res.setHeader('Content-Type','application/json');
    return res.end(JSON.stringify({year:2026,entities:Array.from({length:60},(_,i)=>({path:'accounts/'+i,kind:'accounts',name:'Compte '+i,current:1200,opening:1000,delta:200,percent:20,estimated:true,unexplained:0,monthly:Array(12).fill(20),counts:Array(12).fill(2),closing:Array.from({length:12},(_,m)=>1000+m*20)}))}));
  }
  if (name === '/api/documents/query') {
    let body = '';
    for await (const chunk of req) body += chunk;
    const {path: collection} = JSON.parse(body);
    const data = collection.endsWith('/categories') ? [
      {name:'Alimentation',type:'expense',color:0xff22c55e},
      {name:'Transport',type:'expense',color:0xff3b82f6},
      {name:'Salaire',type:'income',color:0xff22c55e},
    ] : collection.endsWith('/investments') ? [
      {name:'ETF Monde',investmentType:'etf',balance:3500,holdingAccountId:'0'},
      {name:'Bitcoin',investmentType:'crypto',balance:750,holdingAccountId:'0'},
    ] : collection.endsWith('/accounts') ? [{name:'Compte titres'}] : [];
    res.setHeader('Content-Type','application/json');
    return res.end(JSON.stringify({documents:data.map((data,i)=>({path:`${collection}/${i}`,data})),cursor:null}));
  }
  const file = path.resolve(root, '.' + (name === '/' ? '/index.html' : name));
  if (!file.startsWith(root + path.sep)) return res.writeHead(403).end();
  try {
    const bytes = await readFile(file);
    res.setHeader('Content-Type', ({'.js':'text/javascript','.wasm':'application/wasm',
      '.html':'text/html','.json':'application/json'})[path.extname(file)] || 'application/octet-stream');
    res.end(bytes);
  } catch { res.writeHead(404).end(); }
});

(async () => {
  await mkdir(output, {recursive:true});
  server.listen(0,'127.0.0.1');
  await once(server,'listening');
  let target, socket;
  try {
    target = await (await fetch(debug + '/json/new?about:blank',{method:'PUT'})).json();
    socket = new WebSocket(target.webSocketDebuggerUrl);
    await once(socket,'open');
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
    const send = (method,params={}) => new Promise((resolve,reject) => {
      const key=++id;
      const timer=setTimeout(()=>{pending.delete(key);reject(new Error(`${method} timed out`));},15000);
      pending.set(key,{resolve:value=>{clearTimeout(timer);resolve(value);},
        reject:error=>{clearTimeout(timer);reject(error);}});
      socket.send(JSON.stringify({id:key,method,params}));
    });
    const evaluate = async expression => (await send('Runtime.evaluate',{
      expression,returnByValue:true,
    })).result.value;
    for (const width of [320,390,1280]) {
      await send('Emulation.setDeviceMetricsOverride',{width,height:900,deviceScaleFactor:1,mobile:width<760});
      for (const page of ['simulation','categories','investments','annual']) {
        await send('Page.navigate',{url:'about:blank'});
        await delay(150);
        await send('Page.navigate',{url:`http://127.0.0.1:${server.address().port}/?page=${page}`});
        let ready=false;
        for(let i=0;i<300;i++) {
          const error=await evaluate('document.body?.dataset.fixtureError');
          assert.ok(!error,error);
          ready=await evaluate('document.body?.dataset.fixtureReady === "true"');
          if(ready) break;
          await delay(100);
        }
        assert.ok(ready,'Fixture timed out');
        await delay(700);
        const error=await evaluate('document.body?.dataset.fixtureError');
        assert.ok(!error,error);
        if (page === 'annual' && width < 760) {
          await send('Emulation.setTouchEmulationEnabled',{enabled:true,maxTouchPoints:1});
          const touch=(type,x,y)=>send('Input.dispatchTouchEvent',{type,touchPoints:type==='touchEnd'?[]:[{x,y,id:1}]});
          await touch('touchStart',width/2,165); await touch('touchEnd'); await delay(350);
          await touch('touchStart',width/2,420);
          for(let i=1;i<=12;i++){await touch('touchMove',width/2,420-i*15);await delay(16);}
          await touch('touchEnd'); await delay(300);
          assert.ok(Number(await evaluate('document.body.dataset.scrollOffset || 0'))>20,'Annual list must scroll from the expanded chart');
          console.log('Annual chart-origin scroll passed at '+width+'px');
        }
        const shot=await send('Page.captureScreenshot',{format:'png'});
        await writeFile(path.join(output,`page-tabs-${page}-${width}.png`),Buffer.from(shot.data,'base64'));
        console.log(`${page}: ${width}px, no Flutter errors`);
      }
    }
  } finally {
    socket?.close();
    if(target) await fetch(debug+'/json/close/'+target.id);
    server.close();
  }
})().catch(error=>{console.error(error);process.exitCode=1;});

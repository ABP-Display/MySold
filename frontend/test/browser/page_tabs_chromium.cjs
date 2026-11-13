// Build page_tabs_fixture.dart to build/page-tabs-fixture, then use isolated Edge.
const {createServer} = require('node:http');
const {readFile, writeFile, mkdir} = require('node:fs/promises');
const path = require('node:path');
const {once} = require('node:events');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../../build/page-tabs-fixture');
const output = path.resolve(__dirname, '../../../test-results');
const debug = process.argv[2] || 'http://127.0.0.1:9235';
const language = process.env.FIXTURE_LANG || 'fr';
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
let analysisRequests = 0;
const fixtureData = {
  accounts: Array.from({length: 40}, (_, i) => ({name: i === 0 ? 'Compte titres' : 'Compte '+i, balance:1200, description:'Compte de contrôle'})),
  categories: [{name:'Alimentation',type:'expense',color:0xff22c55e},
    {name:'Transport',type:'expense',color:0xff3b82f6}, {name:'Salaire',type:'income',color:0xff22c55e}],
  investments: [{name:'ETF Monde',investmentType:'etf',balance:3500,holdingAccountId:'0'},
    {name:'Bitcoin',investmentType:'crypto',balance:750,holdingAccountId:'0'}],
};
const server = createServer(async (req, res) => {
  const name = new URL(req.url, 'http://localhost').pathname;
  if (name === '/api/analysis/annual') {
    analysisRequests++;
    res.setHeader('Content-Type','application/json');
    return res.end(JSON.stringify({year:2026,entities:Object.entries(fixtureData).flatMap(([kind,rows])=>rows.map((row,i)=>{
      const current=row.balance??240,opening=Math.round(current/1.2*100)/100,delta=Math.round((current-opening)*100)/100;
      return {path:kind+'/'+i,kind,name:row.name,current,opening:kind==='categories'?null:opening,previous:kind==='categories'?200:null,delta,percent:20,estimated:true,unexplained:0,netFlows:120,valuationChange:delta-120,monthly:Array(12).fill(20),counts:Array(12).fill(2),closing:Array.from({length:12},(_,m)=>Math.round((opening+delta*(m+1)/12)*100)/100)};
    }))}));
  }
  if (name === '/api/documents/get') {
    let body=''; for await (const chunk of req) body += chunk;
    const parts=JSON.parse(body).path.split('/');
    res.setHeader('Content-Type','application/json');
    return res.end(JSON.stringify({data:fixtureData[parts[2]]?.[Number(parts[3])]??null}));
  }
  if (name === '/api/documents/query') {
    let body = '';
    for await (const chunk of req) body += chunk;
    const {path: collection} = JSON.parse(body);
    const data = fixtureData[collection.split('/').at(-1)] ?? [];
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
      for (const page of ['simulation','accounts','categories','investments','annual']) {
        await send('Page.navigate',{url:'about:blank'});
        await delay(150);
        await send('Page.navigate',{url:`http://127.0.0.1:${server.address().port}/?page=${page}&lang=${language}`});
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
        const shot=await send('Page.captureScreenshot',{format:'png'});
        await writeFile(path.join(output,`page-tabs-${language}-${page}-${width}.png`),Buffer.from(shot.data,'base64'));
        if (['accounts','categories','investments'].includes(page)) {
          const name={accounts:'Compte titres',categories:'Alimentation',investments:'ETF Monde'}[page];
          const before=analysisRequests;
          const rect=await evaluate(`(()=>{const e=[...document.querySelectorAll('[role="button"]')].find(e=>(e.getAttribute('aria-label')||'').includes(${JSON.stringify(name)})); if(!e)return null; const r=e.getBoundingClientRect(); return {x:r.x+r.width/2,y:r.y+r.height/2};})()`);
          assert.ok(rect,'Missing item button '+page);
          await send('Input.dispatchMouseEvent',{type:'mousePressed',button:'left',clickCount:1,...rect});
          await send('Input.dispatchMouseEvent',{type:'mouseReleased',button:'left',clickCount:1,...rect});
          await delay(500);
          assert.equal(await evaluate('document.body.dataset.routeName'),'/'+page+'/0');
          assert.equal(analysisRequests,before,'Opening an item must reuse its cached annual summary');
          const detail=await send('Page.captureScreenshot',{format:'png'});
          await writeFile(path.join(output,`entity-${language}-${page}-${width}.png`),Buffer.from(detail.data,'base64'));
          assert.ok(!await evaluate('document.body?.dataset.fixtureError'));
          console.log(page+': item detail and shared analysis cache passed');
          const editLabel={fr:'Modifier',de:'Bearbeiten',ja:'編集',en:'Edit'}[language]||'Modifier';
          const edit=await evaluate(`(()=>{const e=[...document.querySelectorAll('[role="button"]')].find(e=>(e.getAttribute('aria-label')||e.textContent||'').includes(${JSON.stringify(editLabel)})); if(!e)return null; const r=e.getBoundingClientRect(); return {x:r.x+r.width/2,y:r.y+r.height/2};})()`);
          assert.ok(edit,'Missing settings edit action');
          await send('Input.dispatchMouseEvent',{type:'mousePressed',button:'left',clickCount:1,...edit});
          await send('Input.dispatchMouseEvent',{type:'mouseReleased',button:'left',clickCount:1,...edit});
          await delay(400);
          assert.equal(await evaluate('document.body.dataset.routeName'),'/','The original edit form must open');
          assert.ok(!await evaluate('document.body?.dataset.fixtureError'));
          console.log(page+': original settings form opened');
        }
        if (page === 'annual' && width < 760) {
          await send('Emulation.setTouchEmulationEnabled',{enabled:true,maxTouchPoints:1});
          const touch=(type,x,y)=>send('Input.dispatchTouchEvent',{type,touchPoints:type==='touchEnd'?[]:[{x,y,id:1}]});
          await touch('touchStart',width/2,620);
          for(let i=1;i<=12;i++){await touch('touchMove',width/2,620-i*15);await delay(16);}
          await touch('touchEnd'); await delay(300);
          assert.ok(Number(await evaluate('document.body.dataset.scrollOffset || 0'))>20,'Annual list must scroll from the expanded chart');
          console.log('Annual chart-origin scroll passed at '+width+'px');
        }
        console.log(`${page}: ${width}px, no Flutter errors`);
      }
    }
  } finally {
    socket?.close();
    if(target) await fetch(debug+'/json/close/'+target.id);
    server.close();
  }
})().catch(error=>{console.error(error);process.exitCode=1;});

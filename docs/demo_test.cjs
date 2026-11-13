// Development-only static demo checks. Uses an isolated Chromium CDP endpoint.
const {createServer}=require('node:http');
const {readFile,writeFile,mkdir}=require('node:fs/promises');
const path=require('node:path');
const {once}=require('node:events');
const assert=require('node:assert/strict');
const debug=process.argv[2]||'http://127.0.0.1:9235';
const delay=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const output=path.resolve(__dirname,'../test-results');
const server=createServer(async(req,res)=>{
  const name=new URL(req.url,'http://localhost').pathname;
  const file=path.resolve(__dirname,'.'+(name==='/'?'/index.html':name));
  if(!file.startsWith(__dirname+path.sep))return res.writeHead(403).end();
  try{res.setHeader('Content-Type',({'.html':'text/html','.css':'text/css','.js':'text/javascript','.png':'image/png','.ttf':'font/ttf','.otf':'font/otf'})[path.extname(file)]||'application/octet-stream');res.end(await readFile(file));}
  catch{res.writeHead(404).end();}
});
(async()=>{
  await mkdir(output,{recursive:true});server.listen(0,'127.0.0.1');await once(server,'listening');
  let target,socket;
  try{
    target=await(await fetch(debug+'/json/new?about:blank',{method:'PUT'})).json();
    socket=new WebSocket(target.webSocketDebuggerUrl);await once(socket,'open');
    let id=0;const pending=new Map(),errors=[];
    socket.addEventListener('message',event=>{
      const m=JSON.parse(event.data);
      if(m.method==='Runtime.exceptionThrown')errors.push(m.params.exceptionDetails.text);
      if(!m.id)return;const p=pending.get(m.id);pending.delete(m.id);
      m.error?p.reject(new Error(JSON.stringify(m.error))):p.resolve(m.result);
    });
    const send=(method,params={})=>new Promise((resolve,reject)=>{
      const key=++id,timer=setTimeout(()=>reject(new Error(method+' timeout')),15000);
      pending.set(key,{resolve:r=>{clearTimeout(timer);resolve(r);},reject:e=>{clearTimeout(timer);reject(e);}});
      socket.send(JSON.stringify({id:key,method,params}));
    });
    const evaluate=async expression=>(await send('Runtime.evaluate',{expression,returnByValue:true})).result.value;
    await send('Runtime.enable');
    await send('Page.navigate',{url:`http://127.0.0.1:${server.address().port}/`});
    for(let i=0;i<200;i++){if(await evaluate('!!document.querySelector(".month-wrap")'))break;await delay(50);}
    await delay(700);
    for(const width of [320,390,1280]){
      await send('Emulation.setDeviceMetricsOverride',{width,height:900,deviceScaleFactor:1,mobile:width<760});
      for(const route of ['mois','stats','global','profil','accounts','categories','investments','simulation','evolution','report']){
        await evaluate(`location.hash=${JSON.stringify(route)}`);await delay(160);
        const shot=await send('Page.captureScreenshot',{format:'png'});
        await writeFile(path.join(output,`demo-${route}-${width}.png`),Buffer.from(shot.data,'base64'));
        assert.ok(await evaluate('document.documentElement.scrollWidth <= innerWidth'),'Horizontal page overflow: '+route+' '+width);
        assert.equal(await evaluate('localStorage.length + sessionStorage.length'),0);
        assert.equal(await evaluate('document.cookie'),'');
      }
      await evaluate('location.hash="profil"');await delay(100);
      assert.equal(await evaluate('!!document.querySelector("[data-panel=evolution]")'),false);
      await evaluate('location.hash="accounts"');await delay(100);
      await evaluate('document.querySelector("[data-entity=accounts]").click()');await delay(100);
      assert.equal(await evaluate('document.querySelector("h1").textContent'),'Compte courant');
      assert.ok(await evaluate('document.querySelector("main").textContent.includes("Paramètres")'));
      await evaluate('location.hash="profil"');await delay(100);
      const top=await evaluate('document.querySelector("main").getBoundingClientRect().top');
      await evaluate('document.querySelector("[data-demo-privacy]").click()');
      assert.equal(await evaluate('document.getElementById("privacy-tab").hidden'),false);
      assert.equal(await evaluate('document.querySelector("main").getBoundingClientRect().top'),top);
      await evaluate('document.getElementById("privacy-tab").click()');
      assert.equal(await evaluate('document.getElementById("privacy-tab").hidden'),true);
      await evaluate('document.getElementById("theme").click()');
      assert.equal(await evaluate('document.body.dataset.theme'),'light');
      await evaluate('document.getElementById("theme").click()');
      console.log(`Demo ${width}px: 10 routes, privacy overlay, themes and no storage passed`);
    }
    assert.deepEqual(errors,[]);
  }finally{socket?.close();if(target)await fetch(debug+'/json/close/'+target.id);server.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});

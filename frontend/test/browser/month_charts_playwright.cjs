// Build month_charts_fixture.dart to build/month-charts-fixture first.
const {createServer}=require('node:http');
const {readFile,writeFile,mkdir}=require('node:fs/promises');
const path=require('node:path');
const assert=require('node:assert/strict');
const {chromium}=require('playwright');
const root=path.resolve(__dirname,'../../build/month-charts-fixture');
const output=path.resolve(__dirname,'../../../test-results');
let requests=0;
const server=createServer(async(req,res)=>{
  const name=new URL(req.url,'http://localhost').pathname;
  if(name.startsWith('/api/')){requests++;return res.writeHead(500).end();}
  const file=path.resolve(root,'.'+(name==='/'?'/index.html':name));
  if(!file.startsWith(root+path.sep))return res.writeHead(403).end();
  try{const bytes=await readFile(file);res.setHeader('Content-Type',({'.js':'text/javascript','.wasm':'application/wasm','.html':'text/html','.json':'application/json'})[path.extname(file)]||'application/octet-stream');res.end(bytes);}catch{res.writeHead(404).end();}
});
(async()=>{
  await mkdir(output,{recursive:true});
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const browser=await chromium.connectOverCDP(process.argv[2]||'http://127.0.0.1:9236');
  const context=await browser.newContext({viewport:{width:390,height:900},hasTouch:true,isMobile:true});
  const page=await context.newPage();
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  const open=async(type,width,{theme='dark',lang='fr',privacy=false,scale=1}={})=>{
    await page.setViewportSize({width,height:900});
    await page.goto(`http://127.0.0.1:${server.address().port}/?type=${type}&theme=${theme}&lang=${lang}&privacy=${privacy}&scale=${scale}`);
    await page.waitForFunction(()=>document.body.dataset.fixtureReady==='true');
    await page.waitForTimeout(450);
    assert.ok(!await page.evaluate(()=>document.body.dataset.fixtureError),await page.evaluate(()=>document.body.dataset.fixtureError));
  };
  try{
    for(const width of [320,390,1280])for(const type of ['expense','income','investment','transfer']){
      await open(type,width);
      await page.screenshot({path:path.join(output,`month-chart-${type}-${width}.png`)});
      const initial=await page.screenshot();
      assert.ok(initial.length>12000,'Chart must render nonblank content');
      if(type==='investment'){
        await page.getByRole('button',{name:/Semaine 2,/}).tap();
        await page.getByRole('button',{name:'Retour au mois'}).waitFor();
        assert.ok((await page.locator('body').innerText()).includes('150,00'));
        await page.screenshot({path:path.join(output,`month-chart-week-${width}.png`)});
        await page.getByRole('button',{name:'Retour au mois'}).tap();
        await page.getByRole('button',{name:/Semaine 2,/}).waitFor();
      }
      const cdp=await context.newCDPSession(page);
      const x=width/2,y=200;
      await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x,y,id:1}]});
      for(let i=1;i<=10;i++){
        await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x,y:y-i*12,id:1}]});
        await page.waitForTimeout(16);
      }
      await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
      await page.waitForTimeout(250);
      const offset=Number(await page.evaluate(()=>document.body.dataset.scrollOffset||0));
      assert.ok(offset>50,`${type}/${width}: vertical chart-origin scroll blocked (${offset})`);
      assert.equal(await page.getByRole('button',{name:'Retour au mois'}).count(),0,'Scroll must not select a week');
      await cdp.detach();
      assert.ok(!await page.evaluate(()=>document.body.dataset.fixtureError));
      console.log(`${type}: ${width}px, touch scroll and rendering passed`);
    }
    for(const type of ['expense','income','investment','transfer']){
      await open(type,320,{theme:'light',lang:'de',scale:2});
      await page.screenshot({path:path.join(output,`month-chart-light-${type}.png`)});
      await open(type,390,{privacy:true});
      const text=await page.locator('body').innerText();
      assert.ok(!/831|438|450|650/.test(text),'Privacy must hide all chart amounts');
    }
    assert.equal(requests,0,'Charts and drilldown must use loaded data only');
    assert.deepEqual(errors,[]);
    console.log('All chart checks passed; zero API requests.');
  }finally{await context.close();await browser.close();server.close();}
})().catch(e=>{console.error(e);process.exitCode=1;server.close();});

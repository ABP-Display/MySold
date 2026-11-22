const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const path=require('node:path');
const BASE='http://localhost:28086';
const output=path.resolve(__dirname,'../../../test-results');
(async()=>{
  const browser=await chromium.connectOverCDP('http://127.0.0.1:9237');
  const context=await browser.newContext({viewport:{width:390,height:900},hasTouch:true,isMobile:true});
  const page=await context.newPage();
  const errors=[];let queries=0,commits=0;
  page.on('pageerror',e=>errors.push(e.message));
  page.on('request',r=>{
    if(r.url().endsWith('/api/documents/query'))queries++;
    if(r.url().endsWith('/api/documents/commit'))commits++;
  });
  const open=async()=>{
    await page.getByRole('button',{name:/^Filtres/}).tap();
    await page.getByRole('checkbox',{name:'Tout afficher',exact:true}).waitFor();
  };
  const choose=async name=>page.getByRole('checkbox',{name,exact:true}).tap();
  const apply=async()=>{
    await page.getByRole('button',{name:'Appliquer',exact:true}).tap();
    await page.waitForTimeout(250);
  };
  const etf=()=>page.getByRole('button',{name:/ETF Monde ETF/}).last();
  const gold=()=>page.getByRole('button',{name:/Or personnalisé Métaux précieux/}).last();
  try{
    const auth=await context.request.post(BASE+'/api/auth/login',{
      headers:{Origin:BASE,'X-MySold-Request':'1'},
      data:{email:'asset-style-c625ba128d4b@mysold.local',password:'Local-test-asset-style-2026!'},
    });
    assert.equal(auth.status(),200,await auth.text());
    for(const width of [320,390,1440]){
      await page.setViewportSize({width,height:900});
      await page.goto(BASE);
      await page.locator('flt-semantics-placeholder').waitFor({state:'attached'});
      await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
      await page.getByRole('button',{name:'',exact:true}).tap();
      await page.waitForTimeout(250);
      await page.keyboard.type('123456',{delay:70});
      await page.getByRole('button',{name:'Profil',exact:true}).waitFor({timeout:45000});
      await page.getByRole('button',{name:'Profil',exact:true}).tap();
      await page.getByRole('button',{name:/^Investissements/}).tap();
      await etf().waitFor();await gold().waitFor();
      await page.waitForTimeout(500);
      const filter=await page.getByRole('button',{name:/^Filtres/}).boundingBox();
      const add=await page.getByRole('button',{name:'Actif',exact:true}).boundingBox();
      assert.ok(filter.x<add.x,'Filter must be on the left');
      assert.ok(filter.x>=15 && add.x+add.width<=width-15,'Buttons need side margins');
      assert.ok(Math.abs(filter.y+filter.height/2-add.y-add.height/2)<2,'Buttons must be aligned');
      assert.equal(await page.getByRole('tab').count(),0,'No bottom category menu');
      await page.screenshot({path:path.join(output,`investment-filter-page-${width}.png`)});
      const before=queries,writes=commits;
      await open();await choose('ETF');await apply();
      assert.ok(await etf().isVisible());assert.equal(await gold().count(),0);
      await open();
      assert.ok(await page.getByRole('checkbox',{name:'ETF',exact:true}).isChecked());
      await choose('Métaux précieux');
      await page.screenshot({path:path.join(output,`investment-filter-dialog-${width}.png`)});
      await page.getByRole('button',{name:'Annuler',exact:true}).tap();
      assert.equal(await gold().count(),0,'Cancel must preserve applied choice');
      await open();await choose('Métaux précieux');await apply();
      assert.ok(await etf().isVisible());assert.ok(await gold().isVisible());
      await open();await choose('Tout afficher');await choose('Autres');await apply();
      await page.getByRole('group',{name:/^Aucun actif/}).waitFor();
      assert.equal(await etf().count(),0);assert.equal(await gold().count(),0);
      await open();await choose('Tout afficher');await apply();
      assert.ok(await etf().isVisible());assert.ok(await gold().isVisible());
      assert.equal(queries,before,'Filtering must reuse already loaded investments');
      assert.equal(commits,writes,'Filter must never write financial data');
      console.log(`${width}: alignment, multi-select, cancel, empty category, reset and cached data passed`);
    }
    assert.deepEqual(errors,[]);
  }catch(error){
    await page.screenshot({path:path.join(output,'investment-filter-error.png')});
    console.error((await page.locator('body').ariaSnapshot()).slice(0,10000));throw error;
  }finally{await context.close();await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});

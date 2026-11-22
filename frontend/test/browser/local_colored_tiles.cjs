const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const path=require('node:path');
const BASE='http://localhost:28086';
const output=path.resolve(__dirname,'../../../test-results');
(async()=>{
  const browser=await chromium.connectOverCDP('http://127.0.0.1:9237');
  const context=await browser.newContext({viewport:{width:390,height:900},hasTouch:true,isMobile:true});
  const page=await context.newPage();const errors=[];let reads=0,theme='Sombre';
  const now=new Date(),year=now.getFullYear(),month=now.getMonth();
  const categories=[
    ['food','Alimentation',0xff4caf50,'expense'],['home','Logement',0xffef5350,'expense'],
    ['travel','Transports',0xff2196f3,'expense'],['leisure','Loisirs',0xffab47bc,'expense'],
    ['bills','Abonnements',0xffffb300,'expense'],['salary','Salaire',0xff4caf50,'income'],
    ['freelance','Missions',0xff2196f3,'income'],['refund','Remboursements',0xffffb300,'income'],
  ].map(([id,name,color,type])=>({id,data:{name,color,type,icon:0xef37}}));
  const tx=(id,description,type,amount,categoryId,extra={})=>({id,data:{description,type,amount,categoryId,
    fromAccountId:'cash',toAccountId:null,date:{_type:'timestamp',value:new Date(year,month,Math.min(now.getDate(),15),12).toISOString()},...extra}});
  const transactions=[
    tx('1','Courses de test','expense',42.35,'food'),tx('2','Loyer de test','expense',620,'home'),
    tx('3','Transport de test','expense',29.14,'travel'),tx('4','Sortie de test','expense',48.3,'leisure'),
    tx('5','Abonnement de test','expense',15.6,'bills'),tx('6','Salaire de test','income',2000,'salary'),
    tx('7','Mission de test','income',420,'freelance'),tx('8','Remboursement de test','income',35,'refund'),
    tx('9','Investissement or','investment',20,null,{toAccountId:'holding',investmentId:'gold'}),
    tx('10','Investissement ETF','investment',100,null,{toAccountId:'holding',investmentId:'etf'}),
    tx('11','Virement de test','transfer',10,null,{toAccountId:'bank'}),
    tx('12','Retrait or','transfer',5,null,{fromAccountId:'holding',toAccountId:'cash',investmentId:'gold'}),
  ];
  page.on('pageerror',e=>errors.push(e.message));
  await page.route('**/api/documents/get',async route=>{
    const request=route.request().postDataJSON();
    const response=await route.fetch();
    if(/^users\/[^/]+$/.test(request.path)){
      const json=await response.json();json.data={...json.data,theme};
      return route.fulfill({response,json});
    }
    return route.fulfill({response});
  });
  // Read-only fictional data for screenshots: no categories or transactions are saved.
  await page.route('**/api/documents/query',async route=>{
    reads++;const query=route.request().postDataJSON();
    const source=query.path.endsWith('/categories')?categories:query.path.endsWith('/transactions')?transactions:null;
    if(!source)return route.continue();
    const rows=source.filter(row=>(query.filters||[]).every(f=>{
      const actual=row.data[f.field]?.value??row.data[f.field],value=f.value?.value??f.value;
      return f.op==='gte'?actual>=value:f.op==='lt'?actual<value:actual===value;
    })).map(row=>({path:query.path+'/'+row.id,data:row.data}));
    await route.fulfill({json:{documents:rows,cursor:null}});
  });
  const select=async name=>{
    await page.getByRole('tab',{name:new RegExp('^'+name)}).or(page.getByRole('button',{name,exact:true})).first().tap();
    await page.waitForTimeout(350);
  };
  const reveal=async locator=>{
    for(let i=0;i<12;i++){
      const box=await locator.count()>0?await locator.boundingBox():null;
      if(box&&box.y>100&&box.y+box.height<740)return;
      await page.mouse.move((await page.viewportSize()).width/2,440);
      await page.mouse.wheel(0,box&&box.y<100?-220:220);await page.waitForTimeout(250);
    }
    throw Error('Tile could not be revealed');
  };
  try{
    const auth=await context.request.post(BASE+'/api/auth/login',{headers:{Origin:BASE,'X-MySold-Request':'1'},
      data:{email:'asset-style-c625ba128d4b@mysold.local',password:'Local-test-asset-style-2026!'}});
    assert.equal(auth.status(),200,await auth.text());
    for(const style of ['Sombre','Clair']){
      theme=style;
      for(const width of style==='Sombre'?[320,390,1440]:[390]){
        await page.setViewportSize({width,height:900});await page.goto(BASE);
        await page.locator('flt-semantics-placeholder').waitFor({state:'attached'});
        await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
        await page.getByRole('button',{name:'',exact:true}).tap();await page.waitForTimeout(250);
        await page.keyboard.type('123456',{delay:65});
        await page.getByRole('textbox',{name:'Rechercher une transaction',exact:true}).waitFor({timeout:45000});
        await page.waitForTimeout(500);const loaded=reads;
        for(const [type,name,title] of [['expense','Dépenses','Courses de test'],['income','Revenus','Salaire de test'],
          ['investment','Investissements','Or personnalisé'],['transfer','Transferts','Virement de test']]){
          await select(name);
          const tile=page.getByRole('button',{name:new RegExp(title)}).last();
          await reveal(tile);
          await page.screenshot({path:path.join(output,`tiles-${type}-${style}-${width}.png`)});
          await tile.screenshot({path:path.join(output,`tile-${type}-${style}-${width}.png`)});
          await tile.tap();await page.waitForTimeout(250);
          assert.ok((await page.locator('body').ariaSnapshot()).includes(title));
          await page.keyboard.press('Escape');await page.waitForTimeout(250);
        }
        assert.equal(reads,loaded,'Styling and opening details must not trigger extra queries');
        console.log(`${style}/${width}: colored tiles, transaction details and cached data passed`);
      }
    }
    assert.deepEqual(errors,[]);
  }catch(error){await page.screenshot({path:path.join(output,'colored-tiles-error.png')});
    console.error((await page.locator('body').ariaSnapshot()).slice(0,12000));throw error;
  }finally{await context.close();await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});

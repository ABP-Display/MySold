const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const path=require('node:path');
const BASE='http://localhost:28086';
const output=path.resolve(__dirname,'../../../test-results');
(async()=>{
  const browser=await chromium.connectOverCDP('http://127.0.0.1:9237');
  const context=await browser.newContext({viewport:{width:390,height:900},hasTouch:true,isMobile:true});
  const page=await context.newPage();const errors=[];let reads=0;
  const now=new Date(),year=now.getFullYear(),month=now.getMonth()+1;
  page.on('pageerror',e=>errors.push(e.message));
  await page.route('**/api/documents/query',async route=>{
    const query=route.request().postDataJSON();
    if(!query.path.endsWith('/transactions'))return route.continue();
    reads++;const documents=[];
    for(let m=1;m<=month;m++){
      const amount=m===month?220:m*10;
      for(const [id,type,day,value] of [['salary','income',1,m===month?2000:1000+m*50],['early','expense',2,amount*.7],['late','expense',12,amount*.3]]){
        const data={type,amount:value,description:`Fixture ${id} ${m}`,fromAccountId:'cash',toAccountId:null,
          date:{_type:'timestamp',value:new Date(year,m-1,day,12).toISOString()}};
        if((query.filters||[]).every(f=>{
          const actual=f.field==='date'?data.date.value:data[f.field],value=f.value?.value||f.value;
          return f.op==='gte'?actual>=value:f.op==='lt'?actual<value:actual===value;
        }))documents.push({path:query.path+`/${id}-${m}`,data});
      }
    }
    documents.sort((a,b)=>a.data.date.value.localeCompare(b.data.date.value));
    if(query.descending)documents.reverse();
    await route.fulfill({json:{documents,cursor:null}});
  });
  const body=()=>page.locator('body').ariaSnapshot();
  const wheel=async dy=>{
    await page.mouse.move((await page.viewportSize()).width/2,500);
    await page.mouse.wheel(0,dy);await page.waitForTimeout(180);
  };
  const reveal=async locator=>{
    for(let i=0;i<18;i++){
      const box=await locator.count()>0?await locator.boundingBox():null;
      if(box&&box.y>=70&&box.y+box.height<780)return box;
      await wheel(box&&box.y<70?-280:280);
    }
    throw Error('Could not reveal control');
  };
  const reference=()=>page.getByRole('button',{name:/Comparer avec/}).first();
  const types=()=>page.getByRole('button',{name:/Type de transaction/}).first();
  const item=name=>page.getByRole('menuitem',{name,exact:true}).or(page.getByRole('button',{name,exact:true})).last();
  const chooseReference=async name=>{
    await reveal(reference());await reference().tap();await item(name).tap();await page.waitForTimeout(220);
  };
  const waitMean=async()=>{
    for(let i=0;i<100;i++){
      if((await body()).includes(`Moyenne sur ${month-1} mois`))return;
      await page.waitForTimeout(100);
    }throw Error('Average did not load');
  };
  try{
    const auth=await context.request.post(BASE+'/api/auth/login',{headers:{Origin:BASE,'X-MySold-Request':'1'},
      data:{email:'asset-style-c625ba128d4b@mysold.local',password:'Local-test-asset-style-2026!'}});
    assert.equal(auth.status(),200,await auth.text());
    for(const width of [320,390,1440]){
      await page.setViewportSize({width,height:900});await page.goto(BASE);
      await page.locator('flt-semantics-placeholder').waitFor({state:'attached'});
      await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
      await page.getByRole('button',{name:'',exact:true}).tap();await page.waitForTimeout(250);
      await page.keyboard.type('123456',{delay:60});
      await page.getByRole('button',{name:'Stats mensuelles',exact:true}).waitFor({timeout:45000});
      await page.getByRole('button',{name:'Stats mensuelles',exact:true}).tap();await page.waitForTimeout(350);
      await reference().waitFor();
      const initialBox=await reveal(reference());await wheel(initialBox.y-95);
      await page.screenshot({path:path.join(output,`comparison-compact-month-${width}.png`)});
      await chooseReference('Moyenne de l’année');await waitMean();
      const loaded=reads;
      const visibleReference=await reveal(reference());await wheel(visibleReference.y-95);
      const refBox=await reference().boundingBox();
      const plot=page.locator('[flt-semantics-identifier="monthly-comparison-chart"]');
      const plotBox=await plot.boundingBox();
      const limit=width<350?490:430;
      assert.ok(plotBox.y-refBox.y<limit,`Compact controls should precede the plot by under ${limit}px, got ${plotBox.y-refBox.y}`);
      await page.screenshot({path:path.join(output,`comparison-compact-average-${width}.png`)});
      for(const label of ['Revenus','Dépenses','Investissements','Transferts','Reste']){
        await reveal(types());await types().tap();await item(label).tap();await page.waitForTimeout(120);
      }
      await reveal(page.getByRole('button',{name:'Jour',exact:true}));
      await page.getByRole('button',{name:'Jour',exact:true}).tap();
      await page.getByRole('button',{name:'Cumulé',exact:true}).tap();
      await chooseReference('Mois précédent (M-1)');
      await chooseReference('Un autre mois');
      await page.getByRole('button',{name:'Annuler',exact:true}).waitFor();
      await page.getByRole('button',{name:'Annuler',exact:true}).tap();
      await chooseReference('Moyenne de l’année');await waitMean();
      assert.equal(reads,loaded,'Controls must reuse loaded data');
      await reveal(types());await types().tap();await item('Dépenses').tap();
      const finalBox=await reveal(reference());await wheel(finalBox.y-95);
      await page.screenshot({path:path.join(output,`comparison-compact-final-${width}.png`)});
      console.log(`${width}: compact layout, five types, both readings, reference menu and cached data passed`);
    }
    assert.deepEqual(errors,[]);
  }catch(error){await page.screenshot({path:path.join(output,'comparison-compact-error.png')});
    console.error((await body()).slice(0,14000));throw error;
  }finally{await context.close();await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});

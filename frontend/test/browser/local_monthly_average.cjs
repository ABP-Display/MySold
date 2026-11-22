const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const path=require('node:path');
const BASE='http://localhost:28086';
const output=path.resolve(__dirname,'../../../test-results');
(async()=>{
  const browser=await chromium.connectOverCDP('http://127.0.0.1:9237');
  const context=await browser.newContext({viewport:{width:390,height:900},hasTouch:true,isMobile:true});
  const page=await context.newPage();
  const errors=[];let reads=0;
  const now=new Date(),year=now.getFullYear(),month=now.getMonth()+1;
  assert.ok(month>1,'Run this fixture with a completed month in the current year');
  page.on('pageerror',e=>errors.push(e.message));
  // Fictional HTTP read responses only: never create or edit financial data.
  await page.route('**/api/documents/query',async route=>{
    const query=route.request().postDataJSON();
    if(!query.path.endsWith('/transactions'))return route.continue();
    reads++;
    const documents=[];
    for(let m=1;m<=month;m++){
      const amount=m===month?220:m*10;
      for(const [id,type,day,value] of [
        ['salary','income',1,m===month?2000:1000+m*50],
        ['early','expense',2,amount*.7],['late','expense',12,amount*.3],
      ]){
        const data={type,amount:value,description:`Fixture ${id} ${m}`,fromAccountId:'cash',toAccountId:null,
          date:{_type:'timestamp',value:new Date(year,m-1,day,12).toISOString()}};
        const matches=(query.filters||[]).every(filter=>{
          const actual=filter.field==='date'?data.date.value:data[filter.field];
          const value=filter.value?.value||filter.value;
          return filter.op==='gte'?actual>=value:filter.op==='lt'?actual<value:actual===value;
        });
        if(matches)documents.push({path:query.path+`/${id}-${m}`,data});
      }
    }
    documents.sort((a,b)=>a.data.date.value.localeCompare(b.data.date.value));
    if(query.descending)documents.reverse();
    return route.fulfill({json:{documents,cursor:null}});
  });
  const body=()=>page.locator('body').ariaSnapshot();
  const wheel=async dy=>{
    await page.mouse.move((await page.viewportSize()).width/2,500);
    await page.mouse.wheel(0,dy);await page.waitForTimeout(200);
  };
  const average=()=>page.getByRole('button',{name:'Moyenne de l’année',exact:true});
  const reveal=async locator=>{
    for(let step=0;step<18;step++){
      const box=await locator.count()>0?await locator.boundingBox().catch(()=>null):null;
      if(box && box.y>=70 && box.y+box.height<760)return box;
      await wheel(box && box.y<70?-350:350);
    }
    throw Error('Control could not be scrolled into view');
  };
  const waitMean=async()=>{
    for(let attempt=0;attempt<100;attempt++){
      if((await body()).includes(`Moyenne sur ${month-1} mois`))return;
      await page.waitForTimeout(100);
    }
    throw Error('Average failed to finish loading');
  };
  try{
    const login=await context.request.post(BASE+'/api/auth/login',{
      headers:{Origin:BASE,'X-MySold-Request':'1'},
      data:{email:'asset-style-c625ba128d4b@mysold.local',password:'Local-test-asset-style-2026!'},
    });
    assert.equal(login.status(),200,await login.text());
    for(const width of [320,390,1440]){
      await page.setViewportSize({width,height:900});await page.goto(BASE);
      await page.locator('flt-semantics-placeholder').waitFor({state:'attached'});
      await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
      await page.getByRole('button',{name:'',exact:true}).tap();await page.waitForTimeout(250);
      await page.keyboard.type('123456',{delay:70});
      await page.getByRole('button',{name:'Profil',exact:true}).waitFor({timeout:45000});
      await page.getByRole('button',{name:'Profil',exact:true}).tap();
      await page.getByRole('button',{name:/^Comptes /}).waitFor();
      await page.waitForTimeout(350);
      const rows=[];
      for(const name of [/^Comptes /,/^Categories |^Catégories /,/^Investissements /]){
        rows.push(await page.getByRole('button',{name}).boundingBox());
      }
      assert.ok(rows.every(r=>Math.abs(r.x-rows[0].x)<1&&Math.abs(r.width-rows[0].width)<1));
      assert.ok(rows[1].y>=rows[0].y+rows[0].height-1&&rows[2].y>=rows[1].y+rows[1].height-1);
      await page.screenshot({path:path.join(output,`profile-grouped-${width}.png`)});
      await page.getByRole('button',{name:'Stats mensuelles',exact:true}).tap();
      await average().waitFor();
      await reveal(average());
      await page.screenshot({path:path.join(output,`comparison-modes-${width}.png`)});
      await average().tap();await waitMean();
      const snapshot=(await body()).replace(/[\u00a0\u202f]/g,' ');
      const expected=((month-1)*10+10)/2;
      assert.match(snapshot,new RegExp(`Moyenne de l’année (?:[: ]+)?${expected.toFixed(2).replace('.',',')} €`));
      const loaded=reads;
      await reveal(page.getByRole('button',{name:'Un autre mois',exact:true}));
      await page.getByRole('button',{name:'Un autre mois',exact:true}).tap();
      await page.getByRole('button',{name:/^Mois de référence/}).waitFor();
      await average().tap();await waitMean();
      assert.equal(reads,loaded,'Switching comparison mode must reuse loaded months');
      const plot=page.locator('[flt-semantics-identifier="monthly-comparison-chart"]');
      const box=await reveal(plot);
      assert.ok(box.width>160&&box.height>100);
      await page.mouse.move(box.x+box.width*.55,Math.max(80,box.y+70));
      await page.waitForTimeout(150);
      await page.screenshot({path:path.join(output,`comparison-average-chart-${width}.png`)});
      assert.equal(reads,loaded,'Hovering must not issue queries');
      console.log(`${width}: grouped management, average ${expected}, two curves and cache reuse passed`);
    }
    assert.deepEqual(errors,[]);
  }catch(error){
    await page.screenshot({path:path.join(output,'comparison-average-error.png')});
    console.error((await body()).slice(0,15000));throw error;
  }finally{await context.close();await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});

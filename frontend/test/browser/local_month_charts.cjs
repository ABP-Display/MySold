// Real application, real isolated Docker API, fictional data seeded by tool/seed_local_demo.py.
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const {randomUUID}=require('node:crypto');
const {mkdir}=require('node:fs/promises');
const path=require('node:path');
const BASE='http://localhost:28086';
const output=path.resolve(__dirname,'../../../test-results');
const categoriesOnly=process.env.MYSOLD_CATEGORY_CHARTS_ONLY==='1';
(async()=>{
  const browser=await chromium.connectOverCDP('http://127.0.0.1:9237');
  const context=await browser.newContext({viewport:{width:390,height:900},hasTouch:true,isMobile:true});
  const page=await context.newPage();
  const errors=[]; let queries=0;
  let uid, originalTheme;
  const profile=async data=>{
    const result=await context.request.post(BASE+'/api/documents/commit',{
      headers:{Origin:BASE,'X-MySold-Request':'1'},data:{requestId:randomUUID().replaceAll('-',''),
        operations:[{path:'users/'+uid,action:'update',data}]}});
    assert.equal(result.status(),200);
  };
  const unlock=async()=>{
    await page.goto(BASE);
    await page.locator('flt-semantics-placeholder').waitFor({state:'attached'});
    await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
    await page.getByRole('button',{name:'',exact:true}).tap();
    await page.waitForTimeout(250);
    await page.keyboard.type('123456',{delay:80});
    await page.locator('[flt-semantics-identifier="month-chart-expense"]').waitFor({timeout:45000});
    await page.waitForTimeout(800);
  };
  page.on('pageerror',e=>errors.push(e.message));
  page.on('request',r=>{if(r.url().endsWith('/api/documents/query')) queries++;});
  const select=async label=>{
    const tab=page.getByRole('tab',{name:new RegExp('^'+label)});
    await tab.or(page.getByRole('button',{name:label,exact:true})).first().tap();
  };
  try{
    await mkdir(output,{recursive:true});
    const login=await context.request.post(BASE+'/api/auth/login',{headers:{Origin:BASE,'X-MySold-Request':'1'},data:{email:'demo@mysold.local',password:'MySold-local-2026!'}});
    assert.equal(login.status(),200);
    uid=(await login.json()).user.uid;
    const current=await context.request.post(BASE+'/api/documents/get',{
      headers:{Origin:BASE,'X-MySold-Request':'1'},data:{path:'users/'+uid}});
    assert.equal(current.status(),200);
    originalTheme=(await current.json()).data.theme;
    await unlock();
    const before=queries;
    for(const width of [320,390,1440]){
      await page.setViewportSize({width,height:width>=1000?760:900});
      await page.waitForTimeout(300);
      let categoryHeight, categorySearchTop;
      for(const [type,label] of [['expense','Dépenses'],['income','Revenus'],['investment','Investissements'],['transfer','Transferts']]){
        if(categoriesOnly&&!['expense','income'].includes(type))continue;
        await select(label);
        const plot=page.locator(`[flt-semantics-identifier="month-chart-${type}"]`);
        await plot.waitFor();await page.waitForTimeout(300);
        const rect=await plot.boundingBox();
        const search=await page.getByRole('textbox',{name:'Rechercher une transaction'}).boundingBox();
        const heading=page.getByRole('heading',{name:'Budget mensuel',exact:true});
        const initialHeading=await heading.boundingBox();
        assert.ok(rect&&rect.width>200&&rect.height>70,'A real visible chart is required');
        assert.ok(rect.height<=235,`${type}/${width}: compact chart height is ${rect.height}px`);
        assert.ok(search&&search.y<550,`${type}/${width}: the search should follow the chart without excess spacing`);
        if(type==='expense'){categoryHeight=rect.height;categorySearchTop=search.y;}
        else {
          assert.ok(Math.abs(rect.height-categoryHeight)<1,'All four charts must have the same height');
          assert.ok(Math.abs(search.y-categorySearchTop)<1,'All cards must keep the same overall height');
        }
        if(type==='expense'||type==='income'){
          assert.equal(await page.getByRole('button',{name:'Afficher plus',exact:true}).count(),0);
          const content=await plot.ariaSnapshot();
          const labels=type==='expense'
            ? ['Alimentation','Logement','Transports','Loisirs','Santé','Énergie et abonnements','Cadeaux','Divers']
            : ['Salaire','Missions indépendantes','Remboursements','Dividendes','Revenus locatifs','Autres (1)'];
          for(const label of labels) assert.ok(content.includes(label),`${label} must appear without expanding a category list`);
          if(type==='expense') assert.ok(!content.includes('Autres ('),'Expense categories must all be plotted');
          else assert.ok(!content.includes('Cadeaux reçus'),'The sixth income category belongs to the aggregated slice');
        }
        await page.screenshot({path:path.join(output,`local-month-${type}-${width}.png`)});
        if(type==='expense'){
          const x=rect.x+rect.width*.6,y=rect.y+rect.height*.45;
          await page.mouse.move(x,y);
          const tooltip=page.locator('[flt-semantics-identifier="chart-info-tooltip"]');
          await tooltip.waitFor();
          const box=await tooltip.boundingBox();
          assert.ok(box.width<=240&&box.width<rect.width,'Expense information must be compact');
          assert.ok(box.x>=rect.x&&box.x+box.width<=rect.x+rect.width+1,'Expense tooltip stays inside its viewport');
          assert.ok((await tooltip.ariaSnapshot()).includes('€'));
          await page.screenshot({path:path.join(output,`local-expense-hover-${width}.png`)});
          await page.mouse.move(2,2);
          await tooltip.waitFor({state:'detached'});
          await page.touchscreen.tap(x,y);
          await tooltip.waitFor();
          await page.screenshot({path:path.join(output,`local-expense-touch-${width}.png`)});
        }
        if(type==='income'){
          const left=await page.locator('[flt-semantics-identifier="month-pie-plot"]').boundingBox();
          const right=await page.locator('[flt-semantics-identifier="month-pie-legend"]').boundingBox();
          assert.ok(Math.abs(left.width/right.width-2)<.03,'Income chart must use a 2:1 split');
          const beforeSelection=await plot.screenshot();
          const radius=Math.min(190,left.height,left.width-2);
          await page.touchscreen.tap(left.x+left.width/2+radius*.37,left.y+left.height/2);
          await page.waitForTimeout(220);
          assert.ok((await plot.ariaSnapshot()).includes('%'),'A selected slice shows its share');
          assert.ok(!beforeSelection.equals(await plot.screenshot()),'Selection must visibly change the chart');
          assert.ok(Math.abs((await plot.boundingBox()).height-categoryHeight)<1,'Selection must not resize its frame');
          await page.screenshot({path:path.join(output,`local-income-selected-${width}.png`)});
          await page.touchscreen.tap(left.x+left.width/2,left.y+left.height/2);
          await page.waitForTimeout(220);
          assert.ok(!(await plot.ariaSnapshot()).includes('%'),'Tapping the center clears selection');
          const legend=page.locator('[flt-semantics-identifier="month-pie-slice-1"]');
          const entry=await legend.boundingBox();
          await page.mouse.move(entry.x+entry.width/2,entry.y+entry.height/2);
          await page.waitForTimeout(800);
          assert.ok((await plot.ariaSnapshot()).includes('%'),'Legend hover grows the related slice');
          assert.ok(!(await page.locator('body').ariaSnapshot()).includes('€ ·'),
            'Legend hover must not show an annotation');
          await page.screenshot({path:path.join(output,`local-income-legend-hover-${width}.png`)});
          await page.mouse.move(2,2);await page.waitForTimeout(220);
          assert.ok(!(await plot.ariaSnapshot()).includes('%'),'Leaving the legend clears its transient preview');
          await page.mouse.move(left.x+left.width/2+radius*.37,left.y+left.height/2);
          await page.waitForTimeout(800);
          assert.ok((await page.locator('body').ariaSnapshot()).includes('€ ·'),
            'Chart hover must preserve its amount and share annotation');
          await page.screenshot({path:path.join(output,`local-income-chart-hover-${width}.png`)});
          await page.mouse.move(2,2);await page.waitForTimeout(250);
        }
        if(type==='investment'){
          assert.ok(!(await plot.ariaSnapshot()).includes('%'),'Investment bar axis must show money, not percentages');
          assert.equal(await page.locator('[flt-semantics-identifier^="investment-section-"]').count(),4);
          const section=page.locator('[flt-semantics-identifier="investment-section-0"]');
          const box=await section.boundingBox();
          await page.touchscreen.tap(box.x+box.width/2,box.y+box.height/2);
          await page.getByRole('button',{name:'Retour aux sections',exact:true}).waitFor();
          assert.ok(Math.abs((await plot.boundingBox()).height-categoryHeight)<1,'Investment detail must keep its frame');
          await page.screenshot({path:path.join(output,`local-investment-detail-${width}.png`)});
          const pie=await page.locator('[flt-semantics-identifier="month-pie-plot"]').boundingBox();
          const radius=Math.min(190,pie.height,pie.width-2);
          await page.touchscreen.tap(pie.x+pie.width/2+radius*.37,pie.y+pie.height/2);
          await page.waitForTimeout(220);
          assert.ok((await plot.ariaSnapshot()).includes('%'),'Investment detail must use the same selectable pie');
          await page.screenshot({path:path.join(output,`local-investment-selected-${width}.png`)});
          await page.getByRole('button',{name:'Retour aux sections',exact:true}).tap();
        }
        if(type==='transfer'){
          const canvas=page.locator('[flt-semantics-identifier="transfer-sankey-canvas"]');
          await canvas.waitFor();
          assert.ok(await page.locator('[flt-semantics-identifier^="sankey-flow-"]').count()>=2,
            'Each route, including reciprocal transfers, needs a canvas flow');
          const flow=page.locator('[flt-semantics-identifier="sankey-flow-0"]');
          assert.ok((await flow.ariaSnapshot()).includes('350,00'),'Flow amount must be accessible');
          await flow.tap();
          await page.getByRole('button',{name:'Retour au graphique',exact:true}).waitFor();
          await page.waitForTimeout(100);
          assert.ok(Math.abs((await plot.boundingBox()).height-categoryHeight)<1,'Sankey detail must keep its frame');
          assert.ok((await plot.ariaSnapshot()).includes('2 opérations'));
          await page.screenshot({path:path.join(output,`local-transfer-detail-${width}.png`)});
          await page.getByRole('button',{name:'Retour au graphique',exact:true}).tap();
        }
        const session=await context.newCDPSession(page);
        const legend=type==='income'?await page.locator('[flt-semantics-identifier="month-pie-legend"]').boundingBox():null;
        const x=legend?legend.x+legend.width/2:rect.x+rect.width*.5;
        const y=Math.min(650,legend?legend.y+legend.height*.45:rect.y+rect.height*.45);
        await session.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x,y,id:1}]});
        for(let i=1;i<=10;i++){
          await session.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x,y:y-i*10,id:1}]});
          await page.waitForTimeout(16);
        }
        await session.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
        await page.waitForTimeout(150);
        const moved=await heading.count()?await heading.boundingBox():null;
        assert.ok(!moved||moved.y<initialHeading.y-30,`${type}/${width}: scroll must start over the chart`);
        // Return to the top without altering the month or any data.
        await page.mouse.move(width*.5,250);await page.mouse.wheel(0,-3000);await page.waitForTimeout(300);
        await page.mouse.move(2,2);
        await session.detach();
        console.log(`${type}: ${width}px, chart ${Math.round(rect.height)}px, search at ${Math.round(search.y)}px; scroll passed`);
      }
    }
    assert.equal(queries,before,'Chart interactions must reuse cached data');
    await profile({theme:'Clair'});
    await page.setViewportSize({width:390,height:900});
    await unlock();
    for(const [type,label] of [['expense','Dépenses'],['income','Revenus'],['investment','Investissements'],['transfer','Transferts']]){
      if(categoriesOnly&&!['expense','income'].includes(type))continue;
      await select(label);
      await page.locator(`[flt-semantics-identifier="month-chart-${type}"]`).waitFor();
      await page.screenshot({path:path.join(output,`local-month-light-${type}.png`)});
      if(type==='expense'){
        const plot=await page.locator('[flt-semantics-identifier="month-chart-expense"]').boundingBox();
        await page.mouse.move(plot.x+plot.width*.6,plot.y+plot.height*.45);
        await page.locator('[flt-semantics-identifier="chart-info-tooltip"]').waitFor();
        await page.screenshot({path:path.join(output,'local-expense-hover-light.png')});
        await page.mouse.move(2,2);
      }
      if(type==='income'){
        await page.locator('[flt-semantics-identifier="month-pie-slice-1"]').hover();
        await page.waitForTimeout(800);
        const body=await page.locator('body').ariaSnapshot();
        assert.ok(body.includes('%')&&!body.includes('€ ·'),'Light legend previews without a tooltip');
        await page.screenshot({path:path.join(output,'local-income-legend-hover-light.png')});
        await page.mouse.move(2,2);await page.waitForTimeout(220);
      }
    }
    await page.setViewportSize({width:1440,height:900});
    await page.waitForTimeout(300);
    await page.getByRole('button',{name:'Mode discret',exact:true}).tap();
    await page.getByText(/Graphique masqu/).waitFor();
    const masked=await page.locator('body').ariaSnapshot();
    assert.ok(!masked.includes('4 587,50')&&!masked.includes('3 200,00')&&!masked.includes('1 190,00'),'Privacy removes chart amounts from accessible content');
    await page.screenshot({path:path.join(output,'local-month-private.png')});
    await page.getByRole('button',{name:'Montants masqués',exact:true}).tap();
    assert.deepEqual(errors,[]);
    console.log('All local application chart checks passed, including light theme and privacy. No extra query while switching chart tabs.');
  }catch(e){
    await page.screenshot({path:path.join(output,'local-month-error.png')});
    console.error((await page.locator('body').ariaSnapshot()).slice(0,6000));throw e;
  }finally{if(originalTheme !== undefined)await profile({theme:originalTheme}).catch(()=>{});await context.close();await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});

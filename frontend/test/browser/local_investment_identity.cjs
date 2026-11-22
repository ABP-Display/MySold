const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const {randomUUID,createHash}=require('node:crypto');
const path=require('node:path');
const BASE='http://localhost:28086';
const output=path.resolve(__dirname,'../../../test-results');
(async()=>{
  const browser=await chromium.connectOverCDP('http://127.0.0.1:9237');
  const context=await browser.newContext({viewport:{width:390,height:900},hasTouch:true,isMobile:true});
  const page=await context.newPage();
  const headers={Origin:BASE,'X-MySold-Request':'1'};
  const errors=[];let queries=0,uid;
  page.on('pageerror',e=>errors.push(e.message));
  page.on('request',r=>{if(r.url().endsWith('/api/documents/query'))queries++;});
  const api=async(route,data)=>{
    const response=await context.request.post(BASE+'/api/'+route,{headers,data});
    assert.equal(response.status(),200,await response.text());return response.json();
  };
  const commit=ops=>api('documents/commit',{requestId:randomUUID().replaceAll('-',''),
    operations:ops.map(o=>({...o,path:'users/'+uid+(o.path?'/'+o.path:'')}))});
  const read=async p=>(await api('documents/get',{path:'users/'+uid+(p?'/'+p:'')})).data;
  const custom='bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const profile={firstName:'Test identité actifs',theme:'Sombre',currency:'€',currencyCode:'EUR',
    languageCode:'fr',language:'Français',pin:createHash('sha256').update('123456').digest('hex'),
    reconnectionFrequency:'never',investmentCategories:[
      {id:'other',name:'Autres',color:0xff8a96a1,icon:0xef37},
      {id:'etf',name:'ETF',color:0xff8daee0,icon:0xf3da},
      {id:custom,name:'Métaux précieux',color:0xffffb74d,icon:0xf05e7}]};
  const unlock=async()=>{
    await page.goto(BASE);
    await page.locator('flt-semantics-placeholder').waitFor({state:'attached'});
    await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
    await page.getByRole('button',{name:'',exact:true}).tap();await page.waitForTimeout(250);
    await page.keyboard.type('123456',{delay:70});
    await page.getByRole('textbox',{name:'Rechercher une transaction',exact:true}).waitFor({timeout:45000});
    await page.waitForTimeout(500);
  };
  const select=async name=>{
    await page.getByRole('tab',{name:new RegExp('^'+name)}).or(
      page.getByRole('button',{name,exact:true})).first().tap();await page.waitForTimeout(350);
  };
  const open=async name=>{
    await page.getByRole('button',{name:'',exact:true}).last().tap();
    await page.getByRole('button',{name,exact:true}).tap();await page.waitForTimeout(350);
  };
  const icon=async(locator,file)=>{
    const box=await locator.boundingBox();
    await page.screenshot({path:path.join(output,file),
      clip:{x:box.x+14,y:box.y+(box.height-38)/2,width:38,height:38}});
  };
  try{
    const credentials={email:'asset-style-c625ba128d4b@mysold.local',password:'Local-test-asset-style-2026!'};
    let auth=await context.request.post(BASE+'/api/auth/login',{headers,data:credentials});
    if(auth.status()===401)auth=await context.request.post(BASE+'/api/auth/register',{
      headers,data:{...credentials,profile}});
    assert.equal(auth.status(),200,await auth.text());uid=(await auth.json()).user.uid;
    const date={_type:'timestamp',value:new Date().toISOString()};
    await commit([{path:'',action:'update',data:profile},
      {path:'accounts/cash',action:'set',data:{name:'Compte courant',balance:975}},
      {path:'accounts/bank',action:'set',data:{name:'Épargne',balance:110}},
      {path:'accounts/holding',action:'set',data:{name:'Compte titres',balance:0,managedByInvestments:true}},
      {path:'investments/gold',action:'set',data:{name:'Or personnalisé',balance:65,holdingAccountId:'holding',investmentType:custom}},
      {path:'investments/etf',action:'set',data:{name:'ETF Monde',balance:100,holdingAccountId:'holding',investmentType:'etf'}},
      {path:'transactions/invest',action:'set',data:{type:'investment',description:'Investissement',date,amount:20,fromAccountId:'cash',toAccountId:'holding',investmentId:'gold'}},
      {path:'transactions/withdraw',action:'set',data:{type:'transfer',description:'Retrait investissement',date,amount:5,fromAccountId:'holding',toAccountId:'cash',investmentId:'gold'}},
      {path:'transactions/bank',action:'set',data:{type:'transfer',description:'Virement classique',date,amount:10,fromAccountId:'cash',toAccountId:'bank'}}]);
    for(const theme of ['Sombre','Clair']){
      await commit([{path:'',action:'update',data:{theme}}]);
      for(const width of theme==='Sombre'?[320,390,1440]:[390]){
        await page.setViewportSize({width,height:900});await unlock();await select('Investissements');
        await page.mouse.move(width/2,500);await page.mouse.wheel(0,280);await page.waitForTimeout(300);
        const tile=page.getByRole('button',{name:/^Or personnalisé/}).last();await tile.waitFor();
        await icon(tile,`asset-invest-icon-${theme}-${width}.png`);
        await page.screenshot({path:path.join(output,`asset-invest-tile-${theme}-${width}.png`)});
        await tile.tap();await page.waitForTimeout(250);
        assert.ok((await page.locator('body').ariaSnapshot()).includes('Métaux précieux'));
        await page.screenshot({path:path.join(output,`asset-invest-detail-${theme}-${width}.png`)});
        await page.keyboard.press('Escape');await page.waitForTimeout(250);
        await open('Investissement');
        const destination=page.getByRole('button',{name:/^Destination/}).first();await destination.waitFor();
        const before=queries;await destination.tap();
        const gold=page.getByRole('button',{name:/Or personnalisé/}).last();await gold.waitFor();
        assert.ok((await page.locator('body').ariaSnapshot()).includes('Métaux précieux'));
        await gold.screenshot({path:path.join(output,`asset-option-invest-${theme}-${width}.png`)});
        await page.screenshot({path:path.join(output,`asset-invest-options-${theme}-${width}.png`)});
        await gold.tap();await page.waitForTimeout(250);
        await page.screenshot({path:path.join(output,`asset-invest-selected-${theme}-${width}.png`)});
        assert.equal(queries,before,'Selecting an asset must reuse loaded metadata');
        await page.getByRole('button',{name:'Annuler',exact:true}).tap();await page.waitForTimeout(250);
        await select('Transferts');
        await page.mouse.move(width/2,450);await page.mouse.wheel(0,280);await page.waitForTimeout(300);
        const withdrawal=page.getByRole('button',{name:/^Retrait investissement/}).last();
        await icon(withdrawal,`asset-withdraw-icon-${theme}-${width}.png`);
        await page.screenshot({path:path.join(output,`asset-transfer-tiles-${theme}-${width}.png`)});
        await open('Transfert');
        await page.getByRole('button',{name:'Actif vers compte',exact:true}).or(
          page.getByRole('radio',{name:'Actif vers compte',exact:true})).or(
          page.getByRole('checkbox',{name:'Actif vers compte',exact:true})).or(
          page.getByText('Actif vers compte',{exact:true})).first().tap();
        const source=page.getByRole('button',{name:/^Actif source/}).first();await source.waitFor();
        const cached=queries;await source.tap();
        const option=page.getByRole('button',{name:/Or personnalisé/}).last();await option.waitFor();
        await option.screenshot({path:path.join(output,`asset-option-withdraw-${theme}-${width}.png`)});
        assert.ok((await page.locator('body').ariaSnapshot()).includes('Métaux précieux'));
        await option.tap();await page.waitForTimeout(250);
        await page.screenshot({path:path.join(output,`asset-withdraw-selected-${theme}-${width}.png`)});
        assert.equal(queries,cached,'Withdrawal selection must not query again');
        await page.getByRole('button',{name:'Annuler',exact:true}).tap();await page.waitForTimeout(250);
        console.log(`${theme}/${width}: investment and withdrawal icons, asset options and cached selection passed`);
      }
    }
    assert.equal((await read('accounts/cash')).balance,975);
    assert.equal((await read('accounts/holding')).balance,165);
    assert.equal((await read('investments/gold')).balance,65);
    assert.deepEqual(errors,[]);
    console.log('All investment presentation checks passed without changing balances.');
  }catch(error){await page.screenshot({path:path.join(output,'asset-identity-error.png')});
    console.error((await page.locator('body').ariaSnapshot()).slice(0,10000));throw error;
  }finally{await context.close();await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});

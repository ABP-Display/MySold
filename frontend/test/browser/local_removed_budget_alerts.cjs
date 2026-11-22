const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const path=require('node:path');
const BASE='http://localhost:28086';
const output=path.resolve(__dirname,'../../../test-results');
(async()=>{
  const browser=await chromium.connectOverCDP('http://127.0.0.1:9237');
  const context=await browser.newContext({viewport:{width:390,height:900},hasTouch:true,isMobile:true});
  const page=await context.newPage();
  const errors=[],alertRequests=[];
  page.on('pageerror',e=>errors.push(e.message));
  page.on('request',r=>{
    if(r.url().includes('/api/') && /budgetAlerts|lastTriggeredPeriod/.test(r.postData()||'')) {
      alertRequests.push(r.url());
    }
  });
  await page.addInitScript(()=>{
    window.notificationRequests=0;
    if('Notification' in window) Notification.requestPermission=async()=>{
      window.notificationRequests++;return 'denied';
    };
  });
  try{
    const auth=await context.request.post(BASE+'/api/auth/login',{
      headers:{Origin:BASE,'X-MySold-Request':'1'},
      data:{email:'asset-style-c625ba128d4b@mysold.local',password:'Local-test-asset-style-2026!'},
    });
    assert.equal(auth.status(),200,await auth.text());
    for(const width of [320,390,1440]){
      await page.setViewportSize({width,height:900});await page.goto(BASE);
      await page.locator('flt-semantics-placeholder').waitFor({state:'attached'});
      await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
      await page.getByRole('button',{name:'',exact:true}).tap();await page.waitForTimeout(250);
      await page.keyboard.type('123456',{delay:70});
      await page.getByRole('button',{name:'Profil',exact:true}).waitFor({timeout:45000});
      await page.getByRole('button',{name:'Profil',exact:true}).tap();
      await page.getByRole('button',{name:/^Comptes /}).waitFor();
      for(const name of [/^Comptes/,/^Catégories|^Categories/,/^Investissements/]){
        assert.ok(await page.getByRole('button',{name}).count()>0);
      }
      assert.doesNotMatch(await page.locator('body').ariaSnapshot(),/Limites|Alertes budget/);
      await page.screenshot({path:path.join(output,`without-limits-profile-${width}.png`)});
      await page.getByRole('button',{name:/^Paramètres|^Parametres/}).first().tap();
      await page.getByRole('button',{name:/^Préférences avancées/}).waitFor();
      await page.mouse.move(width/2,550);await page.mouse.wheel(0,350);await page.waitForTimeout(250);
      await page.getByRole('button',{name:/^Préférences avancées/}).tap();
      await page.getByRole('switch',{name:/^Masquer les montants/}).waitFor();
      const snapshot=await page.locator('body').ariaSnapshot();
      assert.match(snapshot,/Masquer les montants/);
      assert.match(snapshot,/Retourner pour masquer/);
      assert.doesNotMatch(snapshot,/Notifications|Alertes budgétaires|Rappel mensuel/);
      await page.screenshot({path:path.join(output,`without-limits-preferences-${width}.png`)});
      assert.equal(await page.evaluate(()=>window.notificationRequests),0);
      assert.equal(await page.evaluate(()=>typeof window.mysoldNotify),'undefined');
      assert.equal(await page.evaluate(()=>typeof window.mysoldRequestNotifications),'undefined');
      console.log(`${width}: no Limits entry, no notification settings; privacy controls retained`);
    }
    assert.deepEqual(alertRequests,[],'No obsolete alert reads or writes');
    assert.deepEqual(errors,[]);
  }catch(error){
    await page.screenshot({path:path.join(output,'without-limits-error.png')});
    console.error((await page.locator('body').ariaSnapshot()).slice(0,10000));throw error;
  }finally{await context.close();await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});

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
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  let uid;
  const api=async(route,data)=>{
    const response=await context.request.post(BASE+'/api/'+route,{headers,data});
    assert.equal(response.status(),200,await response.text());return response.json();
  };
  const commit=operations=>api('documents/commit',{requestId:randomUUID().replaceAll('-',''),
    operations:operations.map(o=>({...o,path:'users/'+uid+(o.path?'/'+o.path:'')}))});
  const read=async p=>(await api('documents/get',{path:'users/'+uid+(p?'/'+p:'')})).data;
  const unlock=async()=>{
    await page.goto(BASE);
    await page.locator('flt-semantics-placeholder').waitFor({state:'attached'});
    await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
    await page.getByRole('button',{name:'',exact:true}).tap();await page.waitForTimeout(250);
    await page.keyboard.type('123456',{delay:70});
    await page.getByRole('button',{name:'Profil',exact:true}).waitFor({timeout:45000});
  };
  const investments=async()=>{
    await page.getByRole('button',{name:'Profil',exact:true}).tap();
    await page.getByRole('button',{name:/^Investissements/}).tap();
    await page.getByRole('button',{name:'Gérer les catégories d’investissement',exact:true}).waitFor();
  };
  try{
    const registered=await api('auth/register',{email:'categories-'+randomUUID()+'@mysold.local',
      password:'MySold-categories-local-2026!',profile:{firstName:'Test catégories',theme:'Sombre',
        currency:'€',currencyCode:'EUR',languageCode:'fr',language:'Français',
        pin:createHash('sha256').update('123456').digest('hex'),reconnectionFrequency:'never'}});
    uid=registered.user.uid;
    await commit([{path:'accounts/support',action:'set',data:{name:'Compte titres',balance:0,managedByInvestments:true}},
      {path:'investments/gold',action:'set',data:{name:'Or de test',balance:42.35,holdingAccountId:'support',investmentType:'other'}}]);
    await unlock();await investments();
    await page.screenshot({path:path.join(output,'local-investment-categories-header.png')});
    await page.getByRole('button',{name:'Gérer les catégories d’investissement',exact:true}).tap();
    await page.getByRole('button',{name:'Catégorie',exact:true}).tap();
    await page.getByRole('textbox',{name:/Nom/}).tap();await page.waitForTimeout(150);
    await page.getByRole('textbox',{name:/Nom/}).pressSequentially('Métaux précieux',{delay:60});
    await page.getByRole('button',{name:'Choisir une couleur',exact:true}).tap();
    const hex=page.getByRole('alertdialog').getByRole('textbox');
    await hex.tap();await page.waitForTimeout(100);await hex.press('Control+A');
    await hex.pressSequentially('FFB74D',{delay:70});
    await page.keyboard.press('Tab');
    await page.screenshot({path:path.join(output,'local-investment-category-color.png')});
    await page.getByRole('button',{name:'Valider',exact:true}).tap();
    await page.getByRole('button',{name:'Choisir une icone',exact:true}).tap();
    await page.getByRole('button',{name:'ten_k',exact:true}).waitFor();
    await page.screenshot({path:path.join(output,'local-investment-category-icons.png')});
    await page.getByRole('textbox',{name:/Rechercher une icone/}).pressSequentially('diamond',{delay:80});
    await page.waitForTimeout(300);
    await page.screenshot({path:path.join(output,'local-investment-category-icon-search.png')});
    await page.getByRole('button',{name:'diamond_outlined',exact:true}).tap();
    await page.getByRole('button',{name:'Enregistrer',exact:true}).tap();
    await page.getByRole('button',{name:'Métaux précieux',exact:true}).waitFor();
    await page.waitForTimeout(300);
    const profile=await read('');
    const category=profile.investmentCategories.find(c=>c.name==='Métaux précieux');
    assert.ok(category);assert.equal(category.color,0xffffb74d);
    assert.ok(Number.isInteger(category.icon));
    await page.screenshot({path:path.join(output,'local-investment-categories-list.png')});
    await page.getByRole('button',{name:'Retour',exact:true}).tap();
    await page.getByRole('button',{name:'Actif',exact:true}).tap();
    const assetName=page.getByRole('textbox',{name:/Nom de l.investissement/});
    await assetName.tap();await page.waitForTimeout(150);
    await assetName.pressSequentially('Lingot de test',{delay:60});
    assert.equal((await assetName.inputValue()).toLowerCase(),'lingot de test');
    await page.getByRole('button',{name:/^Type d.actif/}).tap();
    await page.getByRole('button',{name:'Métaux précieux',exact:true}).tap();
    const amount=page.getByRole('textbox',{name:/Valeur actuelle de l.actif/});
    await amount.tap();await page.waitForTimeout(150);
    await amount.pressSequentially('12.50',{delay:60});
    assert.equal(await amount.inputValue(),'12.50');
    await page.getByRole('button',{name:'Ajouter',exact:true}).tap();
    await page.getByRole('button',{name:'Gérer les catégories d’investissement',exact:true}).waitFor();
    assert.equal((await read('accounts/support')).balance,54.85);
    await unlock();await investments();
    for(const width of [320,390,1440]){
      await page.setViewportSize({width,height:900});await page.waitForTimeout(300);
      const tab=page.getByRole('tab',{name:/Métaux précieux/});
      if(width<1000){
        const session=await context.newCDPSession(page);
        for(let swipe=0;swipe<3;swipe++){
          const x=width-35,y=850;
          await session.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x,y,id:1}]});
          for(let i=1;i<=10;i++){
            await session.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:x-(width-70)*i/10,y,id:1}]});
            await page.waitForTimeout(16);
          }
          await session.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
          await page.waitForTimeout(250);
        }
        await session.detach();
      }
      await tab.tap();await page.waitForTimeout(350);
      await page.getByRole('button',{name:/Lingot de test/i}).last().waitFor();
      await page.screenshot({path:path.join(output,`local-investment-custom-tab-${width}.png`)});
    }
    await page.getByRole('button',{name:'Gérer les catégories d’investissement',exact:true}).last().tap();
    assert.ok(await page.getByRole('button',{name:'Cette catégorie contient des actifs.',exact:true}).isDisabled());
    const blocked=await context.request.post(BASE+'/api/documents/commit',{headers,data:{requestId:randomUUID().replaceAll('-',''),
      operations:[{path:'users/'+uid,action:'update',data:{investmentCategories:profile.investmentCategories.filter(c=>c.id!==category.id)}}]}});
    assert.equal(blocked.status(),409);
    assert.deepEqual((await read('')).investmentCategories,profile.investmentCategories);
    assert.deepEqual(errors,[]);
    console.log('Custom category color/icon, asset selector, reload persistence, mobile/desktop tabs and protected deletion passed.');
  }catch(e){await page.screenshot({path:path.join(output,'local-investment-categories-error.png')});
    console.error((await page.locator('body').ariaSnapshot()).slice(0,9000));throw e;
  }finally{await context.close();await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});

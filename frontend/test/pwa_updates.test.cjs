const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {MessageChannel} = require('node:worker_threads');
const CURRENT = '2026.10.23.2145';
const NEXT = '2026.10.23.2200';
const HASH = 'a'.repeat(64);
const template = fs.readFileSync(path.join(__dirname, '../web/pwa_updates.js'), 'utf8');
function browser({supported=true, online=true, version=CURRENT, local=CURRENT, waiting=false, activeVersion=CURRENT, waitingVersion=NEXT, hash=HASH, update, fetchError=false, identifies=true, activatedVersion=NEXT}={}) {
  let reloads=0, fetches=0, updates=0, skips=0;
  const serviceWorker = new EventTarget();
  const state={version, hash};
  const registration={installing:null, update:async()=>{updates++; if(update) await update();}};
  const worker=(build)=>({state:'activated', postMessage(message, ports) {
    if(message.type==='MYSOLD_GET_BUILD') { if(identifies) ports[0].postMessage({build: `${build}-${HASH}`}); return; }
    assert.equal(message.type,'MYSOLD_SKIP_WAITING'); skips++;
    registration.active=worker(activatedVersion);
    registration.waiting=null;
    serviceWorker.controller=registration.active;
    serviceWorker.dispatchEvent(new Event('controllerchange'));
  }});
  registration.active=activeVersion ? worker(activeVersion) : null;
  registration.waiting=waiting ? worker(waitingVersion) : null;
  serviceWorker.controller=registration.active;
  serviceWorker.register=async(url, options)=>{assert.equal(url,'/sw.js');assert.equal(options.updateViaCache,'none');return registration;};
  const location={href:'https://mysold.example/budget?keep=1#month', replace(url){reloads++; this.href=url;}};
  const window={isSecureContext:true,location};
  vm.runInNewContext(template.replace('__MYSOLD_BUILD_VERSION__',local),{
    window,navigator:supported?{serviceWorker,onLine:online}:{onLine:online},
    setTimeout:(fn,delay)=>setTimeout(fn,Math.min(delay,100)),clearTimeout,AbortController,MessageChannel,URL,
    fetch:async(url, options)=>{fetches++;assert.equal(url,'/version.json');assert.equal(options.cache,'no-store');if(fetchError)throw Error('network');return{ok:true,json:async()=>({build:state.version,contentHash:state.hash})};},
  });
  return{window,registration,serviceWorker,state,worker,reloads:()=>reloads,fetches:()=>fetches,updates:()=>updates,skips:()=>skips};
}
test('same build makes one uncached check and reports latest',async()=>{
  const s=browser(); assert.equal(await s.window.mysoldCheckForUpdate(),'latest');assert.equal(s.fetches(),1);assert.equal(s.updates(),0);assert.equal(s.window.mysoldBuildVersion,CURRENT);
});
test('unsupported and offline browsers do not request a version',async()=>{
  for(const [options,expected] of [[{supported:false},'unsupported'],[{online:false},'offline']]){const s=browser(options);assert.equal(await s.window.mysoldCheckForUpdate(),expected);assert.equal(s.fetches(),0);}
});
test('checking never activates or reloads without confirmation',async()=>{
  const s=browser({version:NEXT,waiting:true});assert.equal(await s.window.mysoldCheckForUpdate(),'available');assert.equal(s.window.mysoldUpdateVersion,NEXT);assert.equal(s.reloads(),0);assert.equal(s.skips(),0);
});
test('check waits for installation',async()=>{
  const w=new EventTarget();w.state='installing';
  const s=browser({version:NEXT,update:async()=>{s.registration.installing=w;setImmediate(()=>{w.state='installed';s.registration.waiting=s.worker(NEXT);w.dispatchEvent(new Event('statechange'));});}});
  assert.equal(await s.window.mysoldCheckForUpdate(),'available');
});
test('failed or invalid manifests do not report latest',async()=>{
  assert.equal(await browser({fetchError:true}).window.mysoldCheckForUpdate(),'error');assert.equal(await browser({version:'<html>'}).window.mysoldCheckForUpdate(),'error');
});
test('failed installation reports error',async()=>{
  const s=browser({version:NEXT});s.registration.installing={state:'redundant'};assert.equal(await s.window.mysoldCheckForUpdate(),'error');
});
test('confirmed activation verifies the new controller then navigates once with an uncached URL',async()=>{
  const s=browser({version:NEXT,waiting:true});await s.window.mysoldCheckForUpdate();assert.equal(await s.window.mysoldApplyUpdate(),true);assert.equal(s.skips(),1);assert.equal(s.reloads(),1);
  const url=new URL(s.window.location.href);assert.equal(url.searchParams.get('mysold_update'),NEXT);assert.equal(url.searchParams.get('keep'),'1');assert.equal(url.hash,'#month');
  s.serviceWorker.dispatchEvent(new Event('controllerchange'));assert.equal(s.reloads(),1);
});
test('another tab already activated the correct worker: verify it before reloading',async()=>{
  const s=browser({version:NEXT,activeVersion:NEXT});await s.window.mysoldCheckForUpdate();assert.equal(await s.window.mysoldApplyUpdate(),true);assert.equal(s.reloads(),1);
});
test('regression: old active worker with no waiting update must never trigger a reload loop',async()=>{
  const s=browser({version:NEXT});await s.window.mysoldCheckForUpdate();assert.equal(await s.window.mysoldApplyUpdate(),false);assert.equal(s.reloads(),0);
});
test('legacy worker that cannot identify its build does not cause a blind reload',async()=>{
  const s=browser({version:NEXT,waiting:true,identifies:false});await s.window.mysoldCheckForUpdate();assert.equal(await s.window.mysoldApplyUpdate(),false);assert.equal(s.reloads(),0);assert.equal(s.skips(),0);
});
test('mismatched worker hash cannot activate or reload',async()=>{
  const s=browser({version:NEXT,waiting:true,hash:'b'.repeat(64)});await s.window.mysoldCheckForUpdate();assert.equal(await s.window.mysoldApplyUpdate(),false);assert.equal(s.reloads(),0);assert.equal(s.skips(),0);
});
test('controllerchange to a different build cannot reload',async()=>{
  const s=browser({version:NEXT,waiting:true,activatedVersion:CURRENT});await s.window.mysoldCheckForUpdate();assert.equal(await s.window.mysoldApplyUpdate(),false);assert.equal(s.reloads(),0);
});
test('no update or no check cannot reload',async()=>{
  const s=browser();assert.equal(await s.window.mysoldApplyUpdate(),false);await s.window.mysoldCheckForUpdate();assert.equal(await s.window.mysoldApplyUpdate(),false);assert.equal(s.reloads(),0);
});
test('simultaneous checks and confirmations are coalesced',async()=>{
  const s=browser({version:NEXT,waiting:true});assert.deepEqual(await Promise.all([s.window.mysoldCheckForUpdate(),s.window.mysoldCheckForUpdate()]),['available','available']);assert.equal(s.fetches(),1);
  assert.deepEqual(await Promise.all([s.window.mysoldApplyUpdate(),s.window.mysoldApplyUpdate()]),[true,true]);assert.equal(s.reloads(),1);
});
test('server version changes or rolls back before confirmation: do not reload',async()=>{
  for(const changed of [CURRENT,'2026.10.24.0030']){const s=browser({version:NEXT,waiting:true});await s.window.mysoldCheckForUpdate();s.state.version=changed;assert.equal(await s.window.mysoldApplyUpdate(),false);assert.equal(s.reloads(),0);}
});
test('after a successful update the new running client reports latest',async()=>{
  const s=browser({version:NEXT,waiting:true});await s.window.mysoldCheckForUpdate();await s.window.mysoldApplyUpdate();
  const updated=browser({version:NEXT,local:NEXT,activeVersion:NEXT});assert.equal(await updated.window.mysoldCheckForUpdate(),'latest');assert.equal(updated.window.mysoldUpdateVersion,'');
});

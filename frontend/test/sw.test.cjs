const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const BUILD = '2026.10.24.0030-hash';
const source = fs.readFileSync(require('node:path').join(__dirname, '../web/sw.js'), 'utf8').replace('__MYSOLD_BUILD_ID__', BUILD);
function setup() {
  const handlers={}, deleted=[], requests=[];
  let claims=0, skips=0;
  vm.runInNewContext(source, {
    self:{addEventListener:(type,handler)=>handlers[type]=handler, location:{origin:'https://mysold.test'}, clients:{claim:async()=>claims++}, skipWaiting:async()=>skips++},
    caches:{keys:async()=>['mysold-shell-old',`mysold-shell-${BUILD}`,'flutter-app-cache','flutter-app-manifest','flutter-temp-cache','unrelated'], delete:async key=>deleted.push(key),match:async()=> 'offline-shell'},
    fetch:async(request,options)=>{requests.push({request,options});return 'fresh-shell';}, URL,
  });
  return {handlers,deleted,requests,claims:()=>claims,skips:()=>skips};
}
test('activation removes old MySold/Flutter caches, preserves unrelated and current caches, then claims clients',async()=>{
  const s=setup();let result;s.handlers.activate({waitUntil:promise=>result=promise});await result;
  assert.deepEqual(s.deleted,['mysold-shell-old','flutter-app-cache','flutter-app-manifest','flutter-temp-cache']);assert.equal(s.claims(),1);
});
test('worker identifies its immutable build and only skips waiting on confirmation',async()=>{
  const s=setup();let response;
  s.handlers.message({data:{type:'MYSOLD_GET_BUILD'},ports:[{postMessage:message=>response=message}]});
  assert.equal(response.build,BUILD);assert.equal(s.skips(),0);
  let result;s.handlers.message({data:{type:'MYSOLD_SKIP_WAITING'},waitUntil:promise=>result=promise});await result;assert.equal(s.skips(),1);
});
test('navigation uses the network without HTTP cache; API and version checks remain uncached',async()=>{
  const s=setup();let result;
  s.handlers.fetch({request:{url:'https://mysold.test/?mysold_update=next',method:'GET',mode:'navigate'},respondWith:promise=>result=promise});
  assert.equal(await result,'fresh-shell');assert.equal(s.requests[0].options.cache,'no-store');
  for(const url of ['https://mysold.test/api/documents/get','https://mysold.test/version.json']) s.handlers.fetch({request:{url,method:'GET'},respondWith:()=>assert.fail('Must not cache private/API data')});
});

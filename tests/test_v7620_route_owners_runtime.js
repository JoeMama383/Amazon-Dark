const fs=require('fs'),vm=require('vm'),assert=require('assert');
const source=fs.readFileSync('src/ADOrderAdsPrivacy7620.js','utf8')
  .replace('__AD7620_ORDER_IMAGES__','');
function fixture(shape,loading){
 const nodes={}; const callbacks={};
 const root={attrs:{},setAttribute(k,v){this.attrs[k]=v;},removeAttribute(k){delete this.attrs[k];}};
 const allSelectors={
  '#mobileDataDeleteButton':shape==='landing'?{}:null,
  '#mobileAdPreferenceButton':shape==='landing'?{}:null,
  '#optOutControl':shape==='radio'?{}:null,
  '.a-radio.a-radio-fancy':shape==='radio'?{}:null,
  'a.back-button .back-button-text':(['expanded','collapsed','radio'].includes(shape))?{textContent:'Amazon Advertising Preferences'}:null,
  '.a-size-large':shape==='expanded'?{textContent:'Delete your personal information from our ad systems'}:null,
  '.od-modernized .od-container':shape==='orders'?{}:null
 };
 const page={querySelector(sel){return allSelectors[sel]||null;}};
 const d={readyState:loading?'loading':'complete',
   documentElement:root,
   getElementById(id){return id==='a-page'?page:(nodes[id]||null);},
   createElement(tag){return {tag,style:{},id:'',textContent:''};},
   head:{appendChild(el){nodes[el.id]=el;}},
   addEventListener(event,cb){callbacks[event]=cb;}
 };
 const w={addEventListener(event,cb){callbacks[event]=cb;}};
 const context={document:d,window:w};
 vm.runInNewContext(source,context,{timeout:2000});
 if(loading){assert(callbacks.DOMContentLoaded);callbacks.DOMContentLoaded();}
 if(callbacks.load)callbacks.load();
 const enabled=!!root.attrs['data-ad7620-adprefs'];
 assert(!!nodes['ad7620-order-ads-privacy'],'style emitted');
 return {enabled,css:nodes['ad7620-order-ads-privacy'].textContent};
}
for(const variant of ['landing','expanded','collapsed','radio']){
 for(const loading of [false,true]){
  const result=fixture(variant,loading);
  assert.strictEqual(result.enabled,true,`must theme ${variant}, loading=${loading}`);
  assert(result.css.includes('background:#000!important'));
 }
}
for(const variant of ['orders','unrelated']){
 const result=fixture(variant,true);
 assert.strictEqual(result.enabled,false,`must not color unrelated ${variant}`);
}
const landing=fixture('landing',false);
assert(landing.css.includes('#mobileAdPreferenceButton'));
assert(landing.css.includes('#mobileDataDeleteButton'));
assert(landing.css.includes('.od-milestone-bar:not(.active)'));
assert(!landing.css.includes('background:#303335!important'));
console.log('PASS: v7.620 actual JS route owners (landing without back link; radio; delete; orders; unrelated), doc-ready and delayed-ready');

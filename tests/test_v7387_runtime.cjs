// Execute the extracted shipped programs against finite event/storage fixtures.
const fs=require('fs'),vm=require('vm'),assert=require('assert/strict');
const programs=JSON.parse(fs.readFileSync(0,'utf8'));
const {hydrate,clear,privacy}=programs;
for(const value of Object.values(programs))new vm.Script(value);
function storage(mode='ok') {const map=new Map();return {map,getItem(k){if(mode==='read-fails')throw Error('denied');return map.get(k)||null},setItem(k,v){if(mode==='write-fails')throw Error('quota');if(mode!=='silent')map.set(k,v)},removeItem(k){map.delete(k)}}}
function visit(store,bad=1){let reloads=0;const events={};const cards=Array.from({length:24},(_,i)=>({querySelector(q){if(q.startsWith('.byg-'))return i<24-bad?{}:null;if(q.startsWith('.a-price'))return null;return {}}}));
 const root={querySelectorAll(){return cards}},document={readyState:'loading',querySelector(){return root}};
 const window={addEventListener(e,fn){events[e]=fn}};
 vm.runInNewContext(hydrate,{document,window,sessionStorage:store,location:{reload(){reloads++}}});
 events.load();events.pageshow();return reloads;
}
for(const mode of ['read-fails','write-fails','silent'])assert.equal(visit(storage(mode)),0,mode+' must not authorize reload');
const s=storage();assert.equal(visit(s),1);assert.equal(visit(s),0);assert.equal(visit(s,0),0);assert.equal(s.map.size,0);assert.equal(visit(s),1);
assert.equal(visit(storage(),2),0);assert.equal(visit(storage(),24),0);
const ids=['ad7-twb-child-min','ad7-search-pane-twb','ad7-product-feed-twb','ad7-menu-twb','ad7-checkout7369-twb','ad7-checkout7369-floor','ad7-menu-theme'];const alive=new Set(ids),removedAttrs=[];
vm.runInNewContext(clear,{document:{getElementById:id=>alive.has(id)?{remove(){alive.delete(id)}}:null,documentElement:{removeAttribute:k=>removedAttrs.push(k)}}});
assert.deepEqual([...alive],['ad7-checkout7369-floor','ad7-menu-theme']);assert.deepEqual(removedAttrs,['data-ad7-twb-child']);
// Disabled privacy wrappers must pass through without inspecting input.url or parsing URL.
let fetchCalls=0,beacons=0,reads=0;
function XHR(){};XHR.prototype.open=function(){};XHR.prototype.send=function(){};
const window={fetch(){fetchCalls++;return 42},addEventListener(){}};const navigator={sendBeacon(){beacons++;return false}};
vm.runInNewContext(privacy,{window,navigator,XMLHttpRequest:XHR,URL,WeakMap,location:{href:'https://www.amazon.com/'},document:{getElementsByTagName:()=>[]}});
window.__adPrivacy7117Enabled=false;
const url={get url(){reads++;throw Error('unnecessary lookup')}};
assert.equal(window.fetch(url),42);assert.equal(navigator.sendBeacon(url),false);assert.equal(reads,0);assert.equal(fetchCalls,1);assert.equal(beacons,1);
console.log('PASS: BYG storage failures/repeat visits/hydration, checkout TWB cleanup, disabled Privacy pass-through');

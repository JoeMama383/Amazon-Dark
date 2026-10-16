"""Review ownership changes must remain dynamic without scanning or polling."""
import json
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
helper = (root / 'src/ADRenderScope7640.js').read_text()
assert ''.join(json.loads(line) for line in (root / 'src/ADRenderScope7640.js.inc').read_text().splitlines()) == helper
js = r'''
const vm=require('vm'),assert=require('assert');
let callback, observed, count=0, writes=0, ids={};
function body(){const attrs=new Map();return {
 contains:n=>n.inside, getAttribute:k=>attrs.has(k)?attrs.get(k):null,
 setAttribute:(k,v)=>{writes++;attrs.set(k,v)},removeAttribute:k=>{writes++;attrs.delete(k)}
};}
const c={location:{pathname:'/s'},document:{body:body(),getElementById:id=>ids[id]},
 MutationObserver:function(fn){count++;callback=fn;this.observe=(root,opts)=>{observed=opts}}};
c.window=c;c.top=c;vm.createContext(c);vm.runInContext(SOURCE,c);
const prefix=':is(body:has(#mobile-product-reviews),body:has(#cruise-customer-reviews))';
const css=prefix+' .writeReviewButton{color:white}';
const sheet={tagName:'STYLE',id:'ad7593-review-business',textContent:''};
c.ad7640Style(sheet).textContent=css;
assert(sheet.textContent.includes('body:is(*,#mobile-product-reviews):where([data-ad7642-reviews])'));
assert.equal(count,1);assert.equal(writes,0);
assert.deepEqual([...observed.attributeFilter],['id']);assert(observed.subtree&&observed.childList);
ids['mobile-product-reviews']={inside:true};callback();assert.equal(writes,1);
for(let i=0;i<1000;i++)callback();assert.equal(writes,1);
ids['dp']={inside:true};callback();assert.equal(c.document.body.getAttribute('data-ad7642-reviews'),'reviews mobile product');
delete ids['dp'];callback();assert.equal(c.document.body.getAttribute('data-ad7642-reviews'),'reviews mobile');
ids['cruise-customer-reviews']={inside:true};delete ids['mobile-product-reviews'];callback();assert.equal(writes,4);
ids={};callback();assert.equal(writes,5);
// A new body, late ID assignment, removal, and witness outside body.
c.document.body=body();ids['mobile-product-reviews']={inside:false};callback();assert.equal(writes,5);
ids['mobile-product-reviews'].inside=true;callback();assert.equal(writes,6);
c.ad7640Style(sheet).textContent=css;assert.equal(count,1);
c.document.body=null;callback();c.document.body=body();callback();assert.equal(writes,7);
// The existing callback is timed only while a recorder is armed.
let timed=0;
c.__adThemeWork7637={run:(name,fn,receiver,args)=>{
 assert.equal(name,'s0/review-owner-mutation');timed++;return fn.apply(receiver,args);
}};
ids={};callback([{type:'childList'}]);assert.equal(timed,1);assert.equal(writes,8);
delete c.__adThemeWork7637;callback();assert.equal(timed,1);assert.equal(writes,8);
// Non-hot routes and non-review sheets keep their authored semantics.
for(const path of ['/','/live','/medical','/product-reviews/X']){
 c.location.pathname=path;c.ad7640Style(sheet).textContent=css;assert.equal(sheet.textContent,css);
}
c.location.pathname='/dp/X';c.top={};c.ad7640Style(sheet).textContent=css;assert.equal(sheet.textContent,css);
c.top=c;c.MutationObserver=undefined;assert.equal(c.ad7642ReviewScope(css),css);
console.log('PASS: dynamic review ownership, body replacement, unchanged-state writes, route isolation and fallback');
'''.replace('SOURCE', json.dumps(helper))
subprocess.run(['node'], input=js, text=True, check=True)

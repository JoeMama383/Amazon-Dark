"""The startup control is opt-in, bounded, fresh-document only and reversible."""
from pathlib import Path
import json, subprocess, importlib.util
root=Path(__file__).resolve().parents[1]
source=(root/'src/ADStartupIsolation7643.js').read_text()
assert ''.join(json.loads(x) for x in (root/'src/ADStartupIsolation7643.js.inc').read_text().splitlines())==source
for forbidden in ('querySelector', 'getComputedStyle', 'offsetHeight', 'setTimeout', 'setInterval', 'MutationObserver'):
    assert forbidden not in source
js=r'''
const vm=require('vm'),assert=require('assert');
function setup(mode,path='/s',ready='loading',child=false,preexisting=false){
 const floor=[];let now=0;
 const c={Date:{now:()=>now},performance:{now:()=>now},location:{pathname:path},
 document:{readyState:ready,styleSheets:preexisting?[{ownerNode:{id:'ad7-menu-theme'}}]:[],
 head:{appendChild:s=>floor.push(s)},createElement:()=>({remove(){floor.splice(floor.indexOf(this),1)}})}};
 c.window=c;c.top=child?{}:c;vm.createContext(c);vm.runInContext(SOURCE,c);
 return {api:c.ad7643StartupIsolation(mode,100),floor,expire:()=>now=200};
}
for(const [mode,path,ready,child,prior] of [[0,'/s','loading',false,false],[1,'/','loading',false,false],
 [1,'/s','complete',false,false],[1,'/s','loading',true,false],[1,'/s','loading',false,true]]){
 const f=setup(mode,path,ready,child,prior);assert.equal(f.api.style,null);assert.equal(f.floor.length,0);f.api.restore();
}
for(const mode of [1,2,3]){
 const f=setup(mode),styles=[{id:'ad7-product-feed-theme',textContent:'old'}, {id:'ad7593-review-business',textContent:'old'}];
 const expected=mode===1?[true,true]:mode===2?[true,false]:[false,true];
 styles.forEach((s,i)=>{const held=f.api.style(s,'new'+i,()=>{s.textContent='new'+i});assert.equal(held,expected[i]);if(!held)s.textContent='new'+i;});
 assert.equal(f.api.snapshot().isolationStyles,mode===1?2:1);
 assert.equal(f.floor.length,1);f.api.restore(1,0);assert.equal(f.floor.length,0);
 styles.forEach((s,i)=>assert.equal(s.textContent,'new'+i));f.api.restore();assert.equal(f.api.snapshot().isolationRestored,mode===1?2:1);
 assert.equal(f.api.style(styles[0],'x',()=>{}),false);
}
let f=setup(1),s={id:'ad7-menu-theme'};
f.api.style(s,'first',()=>{s.textContent='first'});f.api.style(s,'latest',()=>{s.textContent='latest'});
assert.equal(f.api.snapshot().isolationStyles,1);assert.equal(f.api.snapshot().isolationBytes,6);f.api.restore();assert.equal(s.textContent,'latest');
f=setup(1);for(let i=0;i<128;i++)assert(f.api.style({id:'ad7-'+i},'x',()=>{}));
assert.equal(f.api.style({id:'ad7-over-cap'},'x',()=>{}),false);assert.equal(f.api.snapshot().isolationFailures,1);f.api.restore();
f=setup(1);f.api.style({id:'ad7-failure'},'x',()=>{throw Error('test')});let restored=false;
f.api.style({id:'ad7-good'},'x',()=>{restored=true});f.api.restore();assert(restored);assert.equal(f.api.snapshot().isolationFailures,1);
f=setup(1);f.expire();assert.equal(f.api.style({id:'ad7-expired'},'x',()=>{}),false);
console.log('PASS: fresh/late routes, mode partitions, repeated writes, exact restore, deadline, failure and 128-style cap');
'''.replace('SOURCE',json.dumps(source))
subprocess.run(['node'],input=js,text=True,check=True)
spec=importlib.util.spec_from_file_location('report',root/'scripts/performance-report.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
text='\n'.join(mod.theme_work_report({'startupIsolationMode':1,'themeWork':[{'documentId':1,'mainFrame':True,'isolationEligible':1,'isolationStyles':5,'isolationBytes':500,'isolationRulesAtStop':2,'isolationAdoptedAtStop':0}]}))
assert 'counterfactual diagnostic' in text and 'Isolation incomplete' in text
text='\n'.join(mod.theme_work_report({'startupIsolationMode':1,'themeWork':[{'documentId':1,'mainFrame':True,'isolationEligible':1,'isolationStyles':5}]}))
assert 'Isolation completion unconfirmed' in text
text='\n'.join(mod.theme_work_report({'startupIsolationMode':1,'themeWork':[{'documentId':1,'mainFrame':True,'isolationLate':1}]}))
assert 'No eligible fresh document' in text
native=(root/'src/ADPerformance7596.inc').read_text()
for key in ('startupIsolationMode','isolationRulesAtStop','isolationFailures','isolationRestored'):
    assert '@"'+key+'"' in native
script=(root/'scripts/performance-probe.sh').read_text()
for mode in ('isolate-css','isolate-core','isolate-followups'):assert mode in script
print('PASS: native sanitization and offline reports preserve requested/actual isolation and reject incomplete evidence')

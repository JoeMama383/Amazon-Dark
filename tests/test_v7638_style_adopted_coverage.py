"""The expensive Interests adopted sheet participates only in explicit trials."""
from pathlib import Path
import json,subprocess
R=Path(__file__).resolve().parents[1];J=(R/'src/ADThemeWork7637.js').read_text()
runner=r'''
const vm=require('vm'),assert=require('assert');
for(const armed of [false,true]){
 let t=0,n=0,timers=new Map(),reads=0;
 const owned={disabled:false,cssRules:new Array(300)},foreign={disabled:false,cssRules:new Array(9000)};
 const doc={hidden:false,readyState:'complete',styleSheets:[],adoptedStyleSheets:[owned,foreign],documentElement:{}};
 Object.defineProperty(doc.documentElement,'offsetHeight',{get(){reads++;t+=1;assert(!foreign.disabled);return 10}});
 const c={document:doc,__ad7554InterestsSheet:owned,Date:{now:()=>100000+t},performance:{now:()=>t,timeOrigin:100000},location:{pathname:'/dp/X'},Math,Number,setTimeout:(fn,ms)=>{timers.set(++n,{fn,ms});return n},clearTimeout:i=>timers.delete(i),addEventListener(){},removeEventListener(){}};
 c.window=c;c.top=c;vm.createContext(c);
 vm.runInContext(SOURCE.replace('__SESSION__','"s"').replace('__DEADLINE__','190000').replace('__STYLE_TRIALS__',String(armed)),c);
 const a=[...timers].find(([id,x])=>x.ms===2000);
 if(!armed){assert(!a);assert.equal(reads,0)}else{
  assert(a);timers.delete(a[0]);a[1].fn();let r=c.__adThemeWork7637.snapshot();
  assert.equal(r.stylePlanned,1);assert.equal(r.styleTrials.length,1);assert.equal(r.styleTrials[0].name,'ad7554-interests-adopted');assert.equal(owned.disabled,false);assert.equal(foreign.disabled,false);
 }
 c.__adThemeWork7637.stop();assert.equal(timers.size,0);
}
'''.replace('SOURCE',json.dumps(J))
r=subprocess.run(['node'],input=runner,text=True,capture_output=True);assert r.returncode==0,r.stderr
assert 'if(styleSpent>=15000)' in J and 'styleQueue.slice(0,24)' in J
assert '@"stylePlanned"' in (R/'src/ADPerformance7596.inc').read_text()
print('PASS: explicit style trials cover owned adopted CSS, exclude app sheets, restore state, retain bounds and stay inactive in normal captures')

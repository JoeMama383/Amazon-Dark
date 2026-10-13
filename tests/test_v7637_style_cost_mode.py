"""Opt-in stylesheet experiment restores each sheet before yielding."""
from pathlib import Path
import json,subprocess,importlib.util
R=Path(__file__).resolve().parents[1];J=(R/'src/ADThemeWork7637.js').read_text()
js=r'''
const vm=require('vm'),assert=require('assert');
function fixture(enabled){
 let t=0,id=0,timers=new Map(),reads=0,fail=false,handlers={},messages=[];
 const sheet={disabled:false,ownerNode:{id:'ad7482-new-menus'},cssRules:new Array(100)};
 const doc={hidden:false,readyState:'complete',styleSheets:[sheet,{disabled:true,ownerNode:{id:'ad7-unused'},cssRules:[]}],adoptedStyleSheets:[],documentElement:{}};
 Object.defineProperty(doc.documentElement,'offsetHeight',{get(){reads++;t+=sheet.disabled?3:11;if(fail&&sheet.disabled)throw Error('flush');return 800}});
 const c={document:doc,Date:{now:()=>100000+t},Math,Number,performance:{now:()=>t,timeOrigin:100000},location:{pathname:'/s'},setTimeout:(fn,ms)=>{timers.set(++id,{fn,ms});return id},clearTimeout:i=>timers.delete(i)};
 c.window=c;c.top=c;c.addEventListener=(n,f)=>(handlers[n]||(handlers[n]=[])).push(f);c.removeEventListener=(n,f)=>{handlers[n]=(handlers[n]||[]).filter(x=>x!==f)};
 c.webkit={messageHandlers:{adThemeWork7637:{postMessage:x=>messages.push(x)}}};vm.createContext(c);
 vm.runInContext(SOURCE.replace('__SESSION__','"s"').replace('__DEADLINE__','190000').replace('__STYLE_TRIALS__',String(enabled)),c);
 function run(ms){const item=[...timers].find(([i,x])=>x.ms===ms);assert(item);timers.delete(item[0]);item[1].fn();}
 return {c,sheet,timers,run,setFail(){fail=true},reads:()=>reads};
}
let f=fixture(false);assert(![...f.timers.values()].some(x=>x.ms===2000));assert.equal(f.reads(),0);f.c.__adThemeWork7637.stop();assert.equal(f.timers.size,0);
f=fixture(true);f.run(2000);assert.equal(f.sheet.disabled,false);let r=f.c.__adThemeWork7637.snapshot();assert.equal(r.styleTrials.length,1);assert.equal(r.styleTrials[0].disableMs,3);assert.equal(r.styleTrials[0].restoreMs,11);f.run(100);assert.equal(f.c.__adThemeWork7637.snapshot().styleState,1);f.c.__adThemeWork7637.stop();assert.equal(f.timers.size,0);
f=fixture(true);f.setFail();f.run(2000);assert.equal(f.sheet.disabled,false);assert.equal(f.c.__adThemeWork7637.snapshot().styleTrials[0].failed,1);f.c.__adThemeWork7637.stop();assert.equal(f.timers.size,0);
f=fixture(true);f.c.document.hidden=true;f.run(2000);assert.equal(f.reads(),0);assert.equal(f.sheet.disabled,false);assert.equal(f.c.__adThemeWork7637.snapshot().styleState,3);f.c.__adThemeWork7637.stop();
'''.replace('SOURCE',json.dumps(J))
r=subprocess.run(['node'],input=js,text=True,capture_output=True);assert r.returncode==0,r.stderr
spec=importlib.util.spec_from_file_location('report',R/'scripts/performance-report.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
text='\n'.join(m.theme_work_report({'styleExperiment':True,'themeWork':[{'documentId':1,'mainFrame':True,'styleMode':1,'styleState':1,'styleTrials':[{'name':'ad7482-new-menus','rules':100,'disableMs':3,'restoreMs':11,'failed':0}]}]}))
assert 'deliberate forced recalculations' in text and 'ad7482-new-menus' in text and '11.0 ms' in text
assert m.flattened({'navigationMs':{'loadEventEnd':0}})['loadEventEnd'] is None
print('PASS: normal capture performs zero style trials; explicit style mode restores sheets on success/error/background, cleans timers, and reports experiment separately from input latency')

"""Execute real diagnostic JS with blocked-loop/input timing and cleanup checks."""
from pathlib import Path
import json,subprocess
r=Path(__file__).resolve().parents[1]
s=(r/'src/ADPerformance7596.js').read_text()
program=r'''
const vm=require('vm'),assert=require('assert');let t=0,id=0,timers=new Map(),frames=new Map(),listeners={};
const c={Number,Math,Date:{now:()=>100000+t},document:{hidden:false},PointerEvent:function(){},performance:{now:()=>t,timeOrigin:100000,getEntriesByType:()=>[]},setTimeout:(f,ms)=>{timers.set(++id,{f,ms});return id},clearTimeout:i=>timers.delete(i),requestAnimationFrame:f=>{frames.set(++id,f);return id},cancelAnimationFrame:i=>frames.delete(i)};
c.window=c;c.addEventListener=(k,f)=>(listeners[k]||(listeners[k]=new Set())).add(f);c.removeEventListener=(k,f)=>listeners[k].delete(f);vm.createContext(c);
function run(){vm.runInContext(SOURCE.replace('__SESSION__','"s"').replace('__DEADLINE__','190000'),c)}run();run();assert.equal(frames.size,1);assert.equal(listeners.pointerdown.size,1);
t=350;let h=[...timers].find(([i,x])=>x.ms===250);timers.delete(h[0]);h[1].f();
listeners.pointerdown.forEach(f=>f({type:'pointerdown',timeStamp:200,value:'SECRET'}));
t=430;let q=[...timers].find(([i,x])=>x.ms===0);timers.delete(q[0]);q[1].f();
let fs=[...frames.values()];frames.clear();fs.forEach(f=>f(t));
let a=c.__adPerformance7596.snapshotInitial();assert.equal(a.bridgeFailed,1);assert.equal(a.inputArrival.maxMs,150);assert.equal(a.inputTaskDelay.maxMs,80);assert.equal(a.inputToNextRAF.maxMs,230);assert.equal(a.eventLoopLag.maxMs,100);assert.equal(a.inputKinds.pointerdown,1);assert.equal(a.slowEvents.length,2);assert(!JSON.stringify(a).includes('SECRET'));
c.__adPerformance7596.stop('native-stop');assert.equal(timers.size,0);assert.equal(frames.size,0);assert(Object.values(listeners).every(s=>s.size===0));assert.equal(c.__adPerformance7596.snapshotInitial().inputArrival.maxMs,150);
'''.replace('SOURCE',json.dumps(s))
p=subprocess.run(['node'],input=program,text=True,capture_output=True);assert p.returncode==0,p.stderr
native=(r/'src/ADPerformance7596.inc').read_text()
assert 'WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES inContentWorld:ADPerfWorld7635()' in native
assert 'contentWorld:ADPerfWorld7635() name:@"adPerformance7596"' in native
assert 'inContentWorld:ADPerfWorld7635() completionHandler:completion' in native
assert 'if(script!=self.navigationScript)[ucc addUserScript:script]' in native
assert 'if(!error)[self inject:web]' in native
assert 'sampleDiagnostics' in native and 'errorCode' in native
assert 'if(!gADPerformanceActive7596||!web.window||!self.program||[self.pendingEvals containsObject:web])return;' in native
print('PASS: actual delayed input/task/RAF/heartbeat measurements, bridge failure fallback, bounded cleanup and isolated document-start lifecycle')

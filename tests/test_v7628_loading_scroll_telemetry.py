"""v7.628: opt-in cumulative snapshots and scroll-start lag survive an early background."""
from pathlib import Path
import json,subprocess,tempfile,sys
R=Path(__file__).resolve().parents[1]
source=(R/'src/ADPerformance7596.js').read_text()
assert ''.join(json.loads(ln) for ln in (R/'src/ADPerformance7596.js.inc').read_text().splitlines())==source
for forbidden in ('querySelector','MutationObserver','innerHTML','location.href','document.body'):
    assert forbidden not in source
js=r'''
const vm=require('vm'),assert=require('assert');
let clock=1000,next=0,timers=new Map(),rafs=new Map(),listeners={},reports=[];
const ctx={Math,Date:{now:()=>clock},Number,document:{hidden:false},performance:{now:()=>clock-1000,timeOrigin:1000,getEntriesByType:()=>[{domInteractive:850}]},
setTimeout:(f,ms)=>{const id=++next;timers.set(id,{f,at:clock+ms});return id},clearTimeout:id=>timers.delete(id),
requestAnimationFrame:f=>{const id=++next;rafs.set(id,f);return id},cancelAnimationFrame:id=>rafs.delete(id)};
ctx.window=ctx;ctx.addEventListener=(name,f)=>{(listeners[name]||(listeners[name]=new Set())).add(f)};
ctx.removeEventListener=(name,f)=>listeners[name].delete(f);
ctx.webkit={messageHandlers:{adPerformance7596:{postMessage:v=>reports.push(JSON.parse(JSON.stringify(v)))}}};
vm.createContext(ctx);
vm.runInContext(SOURCE.replace('__SESSION__','"session"').replace('__DEADLINE__','91000'),ctx);
clock=6001;
for(const [k,v] of [...timers]) if(v.at<=clock){timers.delete(k);v.f()}
assert(reports.length===1&&reports[0].reason==='snapshot',JSON.stringify(reports));
assert.equal(reports[0].scrollGestures,0);
clock=6100;for(const f of listeners['touchstart'])f({});
clock=6130;for(const f of listeners['touchmove'])f({});
clock=8400;for(const f of listeners['scroll'])f({});
clock=11005;for(const [k,v] of [...timers])if(v.at<=clock){timers.delete(k);v.f()}
assert(reports.length===2,JSON.stringify(reports));
assert.equal(reports[1].scrollGestures,1);assert.equal(reports[1].scrollStarted,1);
assert(reports[1].scrollFromMove.maxMs>=2000);
assert.equal(reports[0].documentId,reports[1].documentId);
ctx.__adPerformance7596.stop('native-stop');assert.equal(reports.length,3);
assert.equal([...timers].length,0);
assert(Object.values(listeners).every(x=>x.size===0));
'''.replace('SOURCE',json.dumps(source))
r=subprocess.run(['node'],input=js,text=True,capture_output=True)
assert r.returncode==0,r.stderr or r.stdout
sys.path.insert(0,str(R/'scripts'))
import importlib.util
spec=importlib.util.spec_from_file_location('perf_report',R/'scripts/performance-report.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
assert len(m.latest_documents({'webDocuments':[{'documentId':123,'durationMs':3},{'documentId':123,'durationMs':7},{'documentId':999,'durationMs':1}]}))==2
assert m.latest_documents({'webDocuments':[{'documentId':123,'durationMs':3},{'documentId':123,'durationMs':7}]})[0]['durationMs']==7
# The original v7.627 file has no per-page data: do not treat it as zero latency.
with tempfile.TemporaryDirectory() as td:
    tar=Path('/mnt/data/AmazonDark-v7.627-performance-20261010-194528-37732.tar')
    if tar.exists():
        doc=m.load(tar)
        report=m.brief_report(doc)
        assert '19,566.8 ms' in report and 'no WebKit document report' in report
print('PASS: opt-in cumulative web snapshots, one-time scroll-start input measurement, no DOM scanning, bucket dedupe and empty-Web capture handling')

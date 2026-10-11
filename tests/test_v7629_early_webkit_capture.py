"""v7.629: diagnostics cannot exclude loading pages or fail to report initial WebKit data."""
from pathlib import Path
import subprocess, json, tempfile, importlib.util, sys
R=Path(__file__).resolve().parents[1]
native=(R/'src/ADPerformance7596.inc').read_text()
js=(R/'src/ADPerformance7596.js').read_text()
assert ''.join(json.loads(x) for x in (R/'src/ADPerformance7596.js.inc').read_text().splitlines()) == js
assert '||web.loading)return;' not in native
assert 'if(web.loading){[self.navigationStarts' in native and '[self inject:web];return;' in native
assert 'snapshotInitial()' in native
assert 'self.injectionTimings=[NSMutableArray array]' in native
assert '@"injectionTimings":[self.injectionTimings copy]' in native
assert 'self.themeEnabledAtArm=gP.enabled' in native
assert 'if(!gP.enabled||armed' not in native
assert 'querySelectorAll' not in js and 'MutationObserver' not in js
node=r'''
const vm=require('vm'),assert=require('assert');
let sent=[],rAF=[],timers=[],listen={};
const context={Number,Math,Date:{now:()=>1000},document:{hidden:false},performance:{now:()=>0,timeOrigin:1000,getEntriesByType:()=>[]},
requestAnimationFrame:f=>{rAF.push(f);return rAF.length},cancelAnimationFrame:()=>{},
setTimeout:(f,ms)=>{timers.push([f,ms]);return timers.length},clearTimeout:()=>{}};
context.window=context;context.addEventListener=(k,f)=>{(listen[k]||(listen[k]=new Set())).add(f)};
context.removeEventListener=(k,f)=>listen[k].delete(f);
context.webkit={messageHandlers:{adPerformance7596:{postMessage:v=>sent.push(v)}}};
vm.createContext(context);vm.runInContext(JS.replace('__SESSION__','"t"').replace('__DEADLINE__','90000'),context);
assert.equal(sent.length,0);
context.__adPerformance7596.snapshotInitial();
assert.equal(sent.length,1);assert.equal(sent[0].reason,'snapshot');
context.__adPerformance7596.snapshotInitial();assert.equal(sent.length,1);
context.__adPerformance7596.stop('native-stop');assert.equal(sent.length,2);
'''.replace('JS',json.dumps(js))
r=subprocess.run(['node'],input=node,text=True,capture_output=True);assert r.returncode==0,r.stderr+r.stdout
sys.path.insert(0,str(R/'scripts'))
spec=importlib.util.spec_from_file_location('report',R/'scripts/performance-report.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
report=m.brief_report({'version':'v7.629','durationMs':90000,'nativeFrames':{},'touchEventAge':{},'lanes':{},
    'webDocuments':[],'injectionTimings':[{'atMs':200,'evalMs':18000,'wasLoading':True,'success':True}],
    'themeEnabledAtArm':False,'controllerTransitions':[{'controllerClass':'SXWebResultsViewController','atMs':450}],
    'webLoadingIntervals':[{'atMs':500,'loadingMs':19000}]})
assert '18,000.0 ms' in report
assert 'Search Results' in report and '19,000.0 ms' in report
assert 'no WebKit document report' in report
print('PASS: during-load diagnostic evaluation, immediate initial WebKit report, opt-in A/B option and missing-document-aware analysis')

"""The performance recorder must keep real WebKit aggregates when postMessage is absent."""
from pathlib import Path
import json, shutil, subprocess, tempfile
r=Path(__file__).resolve().parents[1]
js=(r/'src/ADPerformance7596.js').read_text()
inc=(r/'src/ADPerformance7596.inc').read_text()
assert ''.join(json.loads(line) for line in (r/'src/ADPerformance7596.js.inc').read_text().splitlines()) == js
assert 'querySelectorAll' not in js and 'MutationObserver' not in js
assert 'return report(\'snapshot\')' in js
assert 'return report(\'snapshot\',false)' in js
assert 'self.webEvalAcks++' in inc and '[self acceptWebBody:snapshot origin:@"eval"]' in inc
assert 'self.webBridgeReports++' in inc and '[self acceptWebBody:body origin:@"message"]' in inc
assert '@"webEvalMissing":@(self.webEvalMissing)' in inc
import importlib.util,sys
spec=importlib.util.spec_from_file_location('perf_report',r/'scripts/performance-report.py')
perf=importlib.util.module_from_spec(spec);sys.modules[spec.name]=perf;spec.loader.exec_module(perf)
assert perf.latest_documents({'webDocuments':[{'documentId':9,'durationMs':120,'origin':'message'}, {'documentId':9,'durationMs':40,'origin':'eval'}]})[0]['durationMs']==120
assert 'eval snapshots' in perf.brief_report({'version':'v7.630','lanes':{},'nativeFrames':{},'webDocuments':[], 'webEvalAcks':2,'webBridgeReports':0,'webEvalMissing':1})
node = r'''
const vm=require('vm'),assert=require('assert');
let docs=[], timers=[], rafs=[], listeners={};
const ctx={Date:{now:()=>1000}, Number, Math, document:{hidden:false},
performance:{now:()=>10,timeOrigin:1000,getEntriesByType:()=>[]},
requestAnimationFrame:fn=>{rafs.push(fn);return rafs.length},cancelAnimationFrame:()=>{},
setTimeout:(fn,ms)=>{timers.push([fn,ms]);return timers.length},clearTimeout:()=>{}};
ctx.window=ctx;ctx.addEventListener=(k,fn)=>{(listeners[k]||(listeners[k]=[])).push(fn)};
ctx.removeEventListener=()=>{};
ctx.webkit={messageHandlers:{adPerformance7596:{postMessage:r=>{throw new Error('missing bridge');}}}};
vm.createContext(ctx);vm.runInContext(JS.replace('__SESSION__','"fallback"').replace('__DEADLINE__','91000'),ctx);
const first=ctx.__adPerformance7596.snapshotInitial();
assert(first&&first.session==='fallback'&&first.bridgeAttempted===1&&first.bridgeFailed===1);
assert(first.documentId>=0&&first.documentId<1e9);
assert(typeof first.frames.count==='number'&&Array.isArray(first.frames.buckets));
const second=ctx.__adPerformance7596.snapshotInitial();
assert(second.bridgeAttempted===0&&second.bridgeFailed===0);
ctx.__adPerformance7596.stop('native-stop');
ctx.webkit.messageHandlers.adPerformance7596.postMessage=r=>docs.push(r);
vm.runInContext(JS.replace('__SESSION__','"fallback"').replace('__DEADLINE__','91000'),ctx);
const restored=ctx.__adPerformance7596.snapshotInitial();
assert(restored&&restored.bridgeFailed===0&&docs.length===1);
'''.replace('JS',json.dumps(js))
res=subprocess.run(['node'],input=node,text=True,capture_output=True)
assert res.returncode==0,res.stdout+res.stderr
clang=shutil.which('clang++')
assert clang
with tempfile.TemporaryDirectory() as td:
 p=Path(td)/'snapshot.mm'
 p.write_text('#include "performance_sdk_stubs.h"\n#include "ADPerformance7596.h"\n#include "ADPerformance7596.inc"\n')
 cmd=[clang,'-x','objective-c++','-std=gnu++98','-fsyntax-only','-fobjc-runtime=ios-17.0','-fobjc-arc','-fblocks','-I',str(r/'src'),'-I',str(r/'tests/fixtures'),str(p)]
 res=subprocess.run(cmd,text=True,capture_output=True)
 assert res.returncode==0,res.stdout+res.stderr
print('PASS: real JS eval snapshot fallback; bridge failure reported; native sanitizer shared; ObjC++ gnu++98 syntax')

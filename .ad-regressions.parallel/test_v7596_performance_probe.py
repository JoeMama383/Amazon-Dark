"""Execute the shipped recorder, its inactive timing gate, and one-session export contract."""
from pathlib import Path
import json,os,shutil,subprocess,tempfile
R=Path(__file__).resolve().parents[1]
js=(R/'src/ADPerformance7596.js').read_text()
assert ''.join(json.loads(x) for x in (R/'src/ADPerformance7596.js.inc').read_text().splitlines())==js
program=r'''
const vm=require('vm'),assert=require('assert');
function fixture(support=true){
 let clock=1000,seq=0,rafs=new Map(),timers=new Map(),listeners={},reports=[],obs=[];
 const ctx={console,Number,Math,Date:{now:()=>clock},document:{hidden:false},
 performance:{now:()=>clock-1000,timeOrigin:1000,getEntriesByType:()=>[{responseStart:25,responseEnd:80,domInteractive:90,domContentLoadedEventEnd:95,loadEventEnd:120}]},
 requestAnimationFrame:f=>{rafs.set(++seq,f);return seq},cancelAnimationFrame:i=>rafs.delete(i),
 setTimeout:f=>{timers.set(++seq,f);return seq},clearTimeout:i=>timers.delete(i)};
 ctx.window=ctx;ctx.addEventListener=(n,f)=>{(listeners[n]||(listeners[n]=new Set())).add(f)};ctx.removeEventListener=(n,f)=>listeners[n].delete(f);
 ctx.webkit={messageHandlers:{adPerformance7596:{postMessage:x=>reports.push(x)}}};
 if(support){ctx.PerformanceObserver=class {static supportedEntryTypes=['resource','event','longtask'];constructor(f){this.f=f;obs.push(this)}observe(o){this.kind=o.type}takeRecords(){return []}disconnect(){this.disconnected=true}};}
 vm.createContext(ctx);
 return {ctx,obs,reports,rafs,timers,listeners,run:()=>vm.runInContext(SOURCE.replace('__SESSION__','"test"').replace('__DEADLINE__','91000'),ctx),frame(t){clock=1000+t;let callbacks=[...rafs.values()];rafs.clear();callbacks.forEach(f=>f(t))},emit(n,e){(listeners[n]||[]).forEach(f=>f(e))}};
}
let f=fixture();f.run();f.run();assert.equal(f.rafs.size,1);assert.equal(f.obs.length,3);assert.equal(f.listeners.pointerdown.size,1);
f.frame(10);f.emit('pointerdown',{timeStamp:8,target:{value:'NEVER COLLECT'}});f.frame(100);
f.obs.find(o=>o.kind==='resource').f({getEntries:()=>Array.from({length:4100},()=>({duration:33,initiatorType:'fetch',name:'SECRET_URL'}))});
f.obs.find(o=>o.kind==='longtask').f({getEntries:()=>[{duration:155}]});
f.emit('pagehide',{});assert.equal(f.rafs.size,0);assert.equal(f.timers.size,0);assert(f.obs.every(o=>o.disconnected));assert(Object.values(f.listeners).every(s=>s.size===0));
let p=f.reports[0];assert.equal(p.frames.maxMs,90);assert.equal(p.inputToNextRAF.maxMs,92);assert.equal(p.resources.count,4096);assert.equal(p.resourceEntriesDropped,4);assert.equal(p.longTasks.maxMs,155);assert.equal(p.navigationMs.domInteractive,90);assert(!JSON.stringify(p).includes('SECRET'));assert(!JSON.stringify(p).includes('NEVER COLLECT'));
f.ctx.__adPerformance7596.stop('native-stop');assert.equal(f.reports.length,1);
f.run();assert.equal(f.rafs.size,1); // Same-session bfcache restoration starts a new document window.
f.ctx.__adPerformance7596.stop('native-stop');assert.equal(f.reports.length,2);
f=fixture(false);f.run();for(let i=0;i<70;i++)f.emit('keydown',{timeStamp:0});f.frame(10);f.frame(90001);assert.equal(f.reports[0].reason,'deadline');assert.equal(f.reports[0].inputDropped,6);assert.equal(f.reports[0].supported.length,0);assert.equal(f.rafs.size,0);
'''.replace('SOURCE',json.dumps(js))
r=subprocess.run(['node'],input=program,text=True,capture_output=True);assert r.returncode==0,r.stdout+r.stderr
clang=shutil.which('clang++');assert clang
with tempfile.TemporaryDirectory() as td:
 t=Path(td);mm=t/'probe.mm';mm.write_text('#include "performance_sdk_stubs.h"\n#include "ADPerformance7596.h"\n#include "ADPerformance7596.inc"\n')
 flags=[]
 # Zig's raw clang frontend needs its builtin include directory; Apple clang does not.
 if 'ziglang' in Path(clang).read_text(errors='ignore')[:1024] if Path(clang).stat().st_size<4096 else False:
  import ziglang
  flags=['-isystem',str(Path(ziglang.__file__).parent/'lib/include')]
 r=subprocess.run([clang,'-x','objective-c++','-std=gnu++98','-fsyntax-only','-fobjc-runtime=ios-17.0','-fobjc-arc','-fblocks',*flags,'-I',str(R/'src'),'-I',str(R/'tests/fixtures'),str(mm)],text=True,capture_output=True);assert r.returncode==0,r.stdout+r.stderr
 cpp=t/'scope.cpp';cpp.write_text('''#include <cassert>
typedef bool BOOL;const bool NO=false;class UIEvent;class WKWebView;class UIViewController;
static int clocks=0,records=0;static double t=1;
static double CACurrentMediaTime(){clocks++;return t;}
#include "ADPerformance7596.h"
static void ADPerformanceRecord7596(unsigned lane,double ms){records++;assert(ms>=0);}
int main(){ {ADPerformanceScope7596 s(ADPerfEvent);} assert(clocks==0&&records==0);
gADPerformanceActive7596=true; {ADPerformanceScope7596 s(ADPerfEvent);t=2;} assert(clocks==2&&records==1);
{ADPerformanceScope7596 s(ADPerfEvent);gADPerformanceGeneration7596++;} assert(records==1);
{ADPerformanceScope7596 s(ADPerfEvent);gADPerformanceActive7596=false;} assert(records==1); }
''')
 subprocess.run([clang,'-std=gnu++98','-I',str(R/'src'),str(cpp),'-o',str(t/'scope')],check=True,capture_output=True);subprocess.run([str(t/'scope')],check=True)
 docs=t/'containers/app/Documents';docs.mkdir(parents=True);shared=t/'shared';shared.mkdir();bindir=t/'bin';bindir.mkdir()
 (docs/'AmazonDark-v7.595-probe-status.json').write_text(json.dumps({'bundle':'com.amazon.Amazon','event':'PROBE_BOOTSTRAP','version':'v7.595-buyagain-discover-comparison-probe'}))
 (bindir/'dpkg-query').write_text('#!/bin/sh\necho 7.619~handoff-regression-repair\n');(bindir/'dpkg-query').chmod(0o755)
 env=dict(os.environ,AD_UI_CONTAINERS=str(t/'containers'),AD_UI_SHARED=str(shared),PATH=str(bindir)+os.pathsep+os.environ['PATH'])
 helper=str(R/'scripts/performance-probe.sh');subprocess.run(['sh',helper,'arm'],env=env,check=True,capture_output=True)
 assert (docs/'AmazonDark-v7.619-performance.arm').exists()
 # An older completed JSON cannot be exported for a newly armed/running session.
 (docs/'AmazonDark-v7.619-performance.json').write_text('{"session":"old"}')
 assert subprocess.run(['sh',helper,'export'],env=env,capture_output=True).returncode!=0
 (docs/'AmazonDark-v7.619-performance.state').write_text('completed\n');(docs/'AmazonDark-v7.619-performance.json').write_text('{"session":"new"}')
 subprocess.run(['sh',helper,'export'],env=env,check=True,capture_output=True)
 import tarfile
 with tarfile.open(next(shared.glob('*.tar'))) as archive:
  assert archive.getnames()==['AmazonDark-v7.619-performance.json'];assert json.load(archive.extractfile(archive.getnames()[0]))['session']=='new'
print('PASS: bounded performance recorder, unsupported WebKit entries, reinjection, bfcache, cleanup, privacy, C++98 inactive gate, native syntax and one-session TAR export')

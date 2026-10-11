"""Perf regression: checkout-specific CSS cannot style /s or /dp at startup.
Source and Node behavior contract only; device benchmarks still required.
"""
from pathlib import Path
import re,subprocess,json
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text()
perf=(R/'src/ADPerformance7596.inc').read_text()
checkout=T[T.index('static NSString *ADCheckoutFloorJS7369'):T.index('static NSString *ADCheckoutTWBJS7369')]
assert checkout.count(':has(')>=100
# Keep historical checkout payloads byte-identical; skip at shared WKUserScript.
shared=T[T.index('static WKUserScript *ADSharedUserScript7387'):T.index('static void ADAttachScriptsToUCC710')]
assert 'if(slot==4 || slot==5 || slot==6)' in shared
assert 'initWithSource:program' in shared
assert 'initWithSource:source()' not in shared
m=re.search(r'NSString \*routeGate=@"(.*?)";', shared)
assert m,'route gate missing'
for pth,should_theme in [('/s',False),('/s/query',False),('/dp',False),('/dp/ASIN',False),('/gp/product/ASIN',False),('/gp/aw/d/ASIN',False),('/cart',True),('/gp/buy/checkout',True),('/gp/your-account',True)]:
    wrapper=m.group(1)+"globalThis.__payloadRan=true;})();"
    harness=("const vm=require('vm'),assert=require('assert');"+
            'const ctx={location:{pathname:'+json.dumps(pth)+'},__payloadRan:false};'+
            'vm.runInNewContext('+json.dumps(wrapper)+',ctx);'+
            'assert.strictEqual(ctx.__payloadRan,'+str(should_theme).lower()+');')
    result=subprocess.run(['node','-'],input=harness,text=True,capture_output=True)
    assert result.returncode==0,(pth,result.stderr)
assert 'if (!fromInteraction)' in (R/'src/ADNewMenus7622.js').read_text()
assert 'doc.body.innerText' in (R/'src/ADNewMenus7622.js').read_text()
assert 'recognizeFeedback(true)' in (R/'src/ADNewMenus7622.js').read_text()
assert 'timerWithTimeInterval:5 target:self selector:@selector(sampleWeb:)' in perf
assert 'if(!web||!web.window)continue;' in perf  # samples during loading
assert 'window.__adPerformance7596.snapshotInitial()' in perf
assert '[self.webSampleTimer invalidate]' in perf
assert '@"webPeriodicSamples":@(self.webPeriodicSamples)' in perf
assert '@"webPeriodicFailures":@(self.webPeriodicFailures)' in perf
assert 'gADPerformanceActive7596' in perf
assert 'self.webs.allObjects' in perf
print('PASS: checkout 107 :has selectors do not activate on Search/PDP; other routes intact; feedback no automatic Search/PDP forced layout; armed WebKit sampled every 5s')

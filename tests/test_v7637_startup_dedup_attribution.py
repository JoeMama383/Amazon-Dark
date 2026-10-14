"""Startup regression: real hook behavior + executed production wrapper/recorder.
No VM timing is presented as a browser/device performance benchmark.
"""
from pathlib import Path
import json,re,subprocess,tempfile,shutil
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text();P=(R/'src/ADPerformance7596.inc').read_text()
W=(R/'src/ADThemeProgram7637.js').read_text();J=(R/'src/ADThemeWork7637.js').read_text()
for name,source in [('ADThemeProgram7637',W),('ADThemeWork7637',J)]:
 assert ''.join(json.loads(x) for x in (R/f'src/{name}.js.inc').read_text().splitlines())==source
# Execute the actual hook body (Foundation operations replaced by fixture calls).
hook=T.split('- (void)removeAllUserScripts {',1)[1].split('\n}',1)[0]
assert hook.index('%orig;')<hook.index('if(gADUserScriptRestoreDepth7637)return;')<hook.index('objc_setAssociatedObject')
keys=re.findall(r'objc_setAssociatedObject\(self,(\w+),nil',hook)
hook=hook.replace('%orig;','originalRemove();').replace('nil','0').replace('OBJC_ASSOCIATION_RETAIN_NONATOMIC','0')
cpp='''#include <vector>
#include <cassert>
struct Prefs {bool enabled;} gP={true};
unsigned gADUserScriptRestoreDepth7637=0; int self=0;
std::vector<int> scripts; bool receipts=true;
void originalRemove(){scripts.clear();}
void objc_setAssociatedObject(int,int,int,int){receipts=false;}
void ADAttachScriptsToUCC710(int){for(int i=1;i<=8;i++)scripts.push_back(i);receipts=true;}
'''+''.join('int '+k+'=0;\n' for k in keys)+'''void removeScripts(){'''+hook+'''}
int main(){
 // App scripts remain in order, while each diagnostic is removed exactly once.
 std::vector<int> authored;authored.push_back(101);for(int i=1;i<=8;i++)authored.push_back(i);authored.push_back(102);
 scripts=authored;
 for(int session=0;session<30;session++){
  std::vector<int> keep=scripts;
  gADUserScriptRestoreDepth7637++;removeScripts();scripts.push_back(201);scripts.push_back(202);
  scripts.insert(scripts.end(),keep.begin(),keep.end());gADUserScriptRestoreDepth7637--;
  assert(receipts&&scripts.size()==authored.size()+2);
  keep=scripts;gADUserScriptRestoreDepth7637++;removeScripts();
  for(unsigned i=0;i<keep.size();i++)if(keep[i]!=201&&keep[i]!=202)scripts.push_back(keep[i]);
  gADUserScriptRestoreDepth7637--;assert(scripts==authored&&receipts);
 }
 // Ordinary Amazon-driven removal still reinstalls all production scripts.
 removeScripts();assert(scripts.size()==8&&receipts);
 // Removing the guard reproduces the historical failure (8 extra scripts).
 scripts=authored;std::vector<int> keep=scripts;removeScripts();scripts.insert(scripts.end(),keep.begin(),keep.end());assert(scripts.size()==authored.size()+8);
}
'''
with tempfile.TemporaryDirectory() as td:
 src=Path(td)/'hook.cpp';src.write_text(cpp);exe=Path(td)/'hook'
 subprocess.run([shutil.which('g++'),'-std=gnu++98',str(src),'-o',str(exe)],check=True,capture_output=True)
 subprocess.run([str(exe)],check=True)
# Verify the two native transactions actually guard remove + restoration, with
# exception-safe guard release; and that both precede production on new views.
assert P.count('gADUserScriptRestoreDepth7637++;')==2
assert P.count('@finally{gADUserScriptRestoreDepth7637--;}')==2
assert '[ucc addUserScript:self.themeScript];[ucc addUserScript:self.navigationScript];' in P
assert 'if(script!=self.themeScript){if(script!=self.navigationScript)[ucc addUserScript:script];}' in P
assert T.index('ADPerformanceAttach7637(ucc);')<T.index('ADSharedUserScript7387(0,ADCoreWebJS7271')
frame=T.split('static void ADForceChildFrameTheme7440(WKWebView *wv){',1)[1].split('@interface ADFrameOwnerBridge7440',1)[0]
assert '}else if([web respondsToSelector:frames])' in frame
assert 'kADFramePassPending7637' in frame and 'kADFramePassAgain7637' in frame
assert 'dispatch_after' not in frame
# Actual JS wrapper: original calls/arguments/this, exceptions, passive/once and
# opt-out path are preserved; startup and callback timings remain distinguishable.
program=r'''
const vm=require('vm'),assert=require('assert');
let t=0,seq=0,timers=new Map(),handlers={},reports=[];
const c={Date:{now:()=>100000+t},performance:{now:()=>t,timeOrigin:100000},Math,Number,
 document:{styleSheets:[{ownerNode:{id:'ad7482-new-menus'},cssRules:[1,2,3]},{ownerNode:{id:'PRIVATE'},cssRules:[1]}],adoptedStyleSheets:[]},
 location:{pathname:'/dp/PRIVATE'},setTimeout:(f,ms)=>{timers.set(++seq,f);return seq},clearTimeout:i=>timers.delete(i)};
c.window=c;c.addEventListener=(type,fn,options)=>{(handlers[type]||(handlers[type]=[])).push({fn,options})};
c.removeEventListener=(type,fn)=>{handlers[type]=(handlers[type]||[]).filter(x=>x.fn!==fn)};
c.webkit={messageHandlers:{adThemeWork7637:{postMessage:x=>reports.push(JSON.parse(JSON.stringify(x)))}}};
c.getComputedStyle=()=>{t+=7;return{color:'PRIVATE'}};vm.createContext(c);
function wrap(body){return WRAPPER.replace('__SLOT__','0').replace('__PROGRAM__',body)}
vm.runInContext(RECORDER.replace('__SESSION__','"s"').replace('__DEADLINE__','190000').replace('__STYLE_TRIALS__','false'),c);
c.burn=ms=>{t+=ms};
const payload="ad7637Listen(window,'click',function ownHandler(e){burn(20);this.received=e;return 41;},{once:true,passive:true});burn(12);ad7637Computed(document);";
vm.runInContext(wrap(payload),c);
let listener=handlers.click[0];assert(listener.options.once&&listener.options.passive);
let receiver={},event={secret:'NEVER CAPTURE'};assert.equal(listener.fn.call(receiver,event),41);assert.equal(receiver.received,event);
let out=c.__adThemeWork7637.snapshot();assert.equal(out.route,2);assert.equal(out.themeSheets,1);assert.equal(out.themeRules,3);
assert.equal(out.metrics.find(x=>x.name==='s0/install').maxMs,19);
assert.equal(out.metrics.find(x=>x.name==='s0/computed-style').maxMs,7);
assert.equal(out.metrics.find(x=>x.name.includes('ownHandler')).maxMs,20);
assert(!JSON.stringify(out).includes('PRIVATE')&&!JSON.stringify(out).includes('NEVER CAPTURE'));
assert.throws(()=>c.__adThemeWork7637.run('s0/error',()=>{t+=10;throw new Error('original');},null,[]),/original/);
assert.equal(c.__adThemeWork7637.snapshot().metrics.find(x=>x.name==='s0/error').maxMs,10);
for(let i=0;i<180;i++)c.__adThemeWork7637.run('s0/x'+i,()=>{t+=10},null,[]);
out=c.__adThemeWork7637.snapshot();assert.equal(out.metrics.length,96);assert.equal(out.slowCalls.length,64);assert(out.dropped>0);
c.__adThemeWork7637.stop();assert.equal(timers.size,0);assert(!c.__adThemeWork7637);
assert.equal(handlers.pagehide.length,0);assert.equal(handlers.load.length,0);
// Listeners keep original semantics after recorder teardown, with no clock calls.
c.performance.now=()=>{throw Error('inactive clock')};listener.fn.call(receiver,event);
vm.runInContext(wrap("ad7637Listen(window,'change',function unarmed(){return 8},false);"),c);
assert.equal(handlers.change[0].fn.name,'unarmed');assert.equal(handlers.change[0].fn(),8);
'''.replace('WRAPPER',json.dumps(W)).replace('RECORDER',json.dumps(J))
r=subprocess.run(['node'],input=program,text=True,capture_output=True);assert r.returncode==0,r.stderr
# Native whitelist and recorder are bounded. No UI inventory or DOM walking.
for bad in ('querySelector','getElementsBy','getBoundingClientRect','getComputedStyle','MutationObserver','requestAnimationFrame','setInterval'):
 assert bad not in J,bad
assert 'self.themeReports.count<128' in P and 'self.scriptInventory.count>=64' in P
print('PASS: actual removal hook survives 30 diagnostic sessions without duplicates; original app removals reinstall; traced own callbacks preserve semantics, bounds, privacy and cleanup; single frame API fallback')
# Freeze all existing JS payloads and their CSS declarations, rather than trusting
# a few selected UI rules. v7.638 explicitly checks the two repaired JS paths separately below.
import hashlib
from payload_source import strings,block
baseline=json.loads((R/'tests/fixtures/theme_payloads_v7636.json').read_text())
def digest(text):
 text=re.sub(r'7\.(636|637|638|639|640)', '7.VERSION', text)
 return hashlib.sha256(text.encode()).hexdigest()
for name,expected in baseline['functions'].items():
 current=strings(block(T,name))
 if name=='ADForcedPDPFrameThemeJS7440':
  legacy=json.loads((R/'tests/fixtures/frame_program_v7637.json').read_text())
  assert digest(legacy)==expected
  # v7.638 changes ownership, not any paint selector/declaration or its scope.
  for expression in (r'var A=(.*?);',r'(?:s.textContent|var css)=`(.*?)`;'):
   assert re.search(expression,current,re.S).group(1)==re.search(expression,legacy,re.S).group(1)
 elif name=='ADNewMenusJS7482':
  # v7.639 adds a cached native composer which branches the unchanged CSS
  # include at run time. Ignore ONLY its four exact Foundation string keys;
  # all other historic menu script components stay under their golden hash.
  keys=('ADNewMenusScope7639.js.incs.textContent=``;\n// v7.594: arc-button'
        'var ad7639AllCSS=``;\n// v7.594: arc-button')
  assert keys in current
  current=current.replace(keys,'',1)
  assert digest(current)==expected,('changed existing payload',name)
 else: assert digest(current)==expected,('changed existing payload',name)
for name,expected in baseline['includes'].items():
 current=(R/'src'/name).read_text()
 if name=='ADNewMenus7622.js.inc':
  code=''.join(json.loads(x) for x in current.splitlines())
  code=code.replace('        // Lifecycle events are objects, not the explicit boolean opt-in.\n','').replace('if (fromInteraction !== true) {','if (!fromInteraction) {')
  current=''.join(json.dumps(x)+'\n' for x in code.splitlines(True))
 assert digest(current)==expected,('changed existing include',name)
# All listener call sites in the shipped programs use the supported receivers.
main=block(T,'ADNewMenusJS7482')
parts=[]
for name in re.findall(r'#include "([^"]+\.js.inc)"',main):
 parts.append(''.join(json.loads(x) for x in (R/'src'/name).read_text().splitlines()))
for name in baseline['functions']:
 if not any(word in name for word in ('Probe','Performance','CoreWeb','NewMenus')):
  parts.append(strings(block(T,name)))
for code in parts:
 assert 'removeEventListener(' not in code
 for receiver in re.findall(r'([\w.]+)\.addEventListener\(',code):
  assert receiver in ('window','document','d','doc'),receiver
print('PASS: all retained theme payloads and CSS unchanged; only the explicit feedback guard and frame-sheet ownership exceptions are permitted; wrapper call-site contract covers every production listener')

# Both standard and prefixed filters receive the same real formatter argument.
order_line=next(x for x in T.splitlines() if 'orderMedia7620=[NSString stringWithFormat:' in x)
assert order_line.count('%.3f')==2 and order_line.endswith(',ad7593Factor,ad7593Factor];')

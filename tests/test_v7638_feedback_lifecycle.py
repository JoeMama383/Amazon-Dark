"""Execute real DOMContentLoaded/pageshow events; neither is a feedback click."""
from pathlib import Path
import json, subprocess, importlib.util
R=Path(__file__).resolve().parents[1]
source=(R/'src/ADNewMenus7622.js').read_text()
assert ''.join(json.loads(x) for x in (R/'src/ADNewMenus7622.js.inc').read_text().splitlines())==source
runner=r'''
const assert=require('assert'),vm=require('vm');
for(const path of ['/s','/s/ref=x','/dp/TEST','/gp/product/TEST','/gp/aw/d/TEST']){
 let reads=0,attrs={},handlers={},timers=[];
 const root={appendChild(){},setAttribute(k,v){attrs[k]=v},removeAttribute(k){delete attrs[k]}};
 const body={get innerText(){reads++;return 'Leave feedback. This ad is not relevant'}};
 const doc={documentElement:root,body,head:root,readyState:'loading',getElementById(){return null},createElement(){return {}},addEventListener(n,f){handlers[n]=f}};
 const c={document:doc,location:{pathname:path},setTimeout(f){timers.push(f)}};
 c.window=c;c.addEventListener=(n,f)=>handlers[n]=f;vm.createContext(c);
 vm.runInContext(SOURCE.replace('__TAME__','true').replace('__FACTOR__','0.684'),c);
 handlers.DOMContentLoaded({type:'DOMContentLoaded'});handlers.pageshow({type:'pageshow',persisted:true});
 assert.equal(reads,0,path+' must not force layout during hydration');
 // Real feedback interactions retain the existing delayed, visible-text check.
 handlers.click({target:{closest(){return true}}});assert.equal(timers.length,2);
 for(const f of timers)f();assert.equal(reads,2);assert.equal(attrs['data-ad7622-feedback'],'1');
}
'''.replace('SOURCE',json.dumps(source))
proc=subprocess.run(['node'],input=runner,text=True,capture_output=True)
assert proc.returncode==0,proc.stderr
spec=importlib.util.spec_from_file_location('report',R/'scripts/performance-report.py')
report=importlib.util.module_from_spec(spec);spec.loader.exec_module(report)
rows=[{'documentId':3,'mainFrame':True,'timeOriginMs':10001.0002,'durationMs':100},
      {'documentId':3,'mainFrame':True,'timeOriginMs':10000,'durationMs':500},
      {'documentId':3,'mainFrame':True,'timeOriginMs':20000,'durationMs':100},
      {'documentId':3,'mainFrame':False,'timeOriginMs':10000,'durationMs':500}]
latest=report.latest_theme_documents({'themeWork':rows})
assert len(latest)==3 and latest[0]['durationMs']==500
native=(R/'src/ADPerformance7596.inc').read_text()
assert 'fabs([self.themeReports[i][@"timeOriginMs"] doubleValue]-[safe[@"timeOriginMs"] doubleValue])<=5.0' in native
print('PASS: actual lifecycle Event objects cannot bypass Search/PDP feedback guard; genuine clicks retain feedback paint; rounded WebKit origins do not double-count theme reports')

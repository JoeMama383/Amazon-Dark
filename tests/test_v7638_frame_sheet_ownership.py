"""Execute production frame payload: one CSS owner, same rules, repair failures."""
from pathlib import Path
import json,re,subprocess
from payload_source import strings,block
R=Path(__file__).resolve().parents[1];T=(R/'src/Tweak.xm').read_text()
old=json.loads((R/'tests/fixtures/frame_program_v7637.json').read_text())
new=strings(block(T,'ADForcedPDPFrameThemeJS7440'))
def prep(s):return re.sub(r'%\.[0-9]+f','0.684',s).replace('%ld','45').replace('%%','%')
runner=r'''
const vm=require('vm'),assert=require('assert');
function fixture(mode){
 const nodes={};let sheets=[];
 const root={setAttribute(){},appendChild(s){nodes[s.id]=s;s.isConnected=true}};
 const doc={head:root,documentElement:root,getElementById:id=>nodes[id],createElement(){return {textContent:'',isConnected:false}}};
 if(mode!=='unsupported')Object.defineProperty(doc,'adoptedStyleSheets',{get(){return sheets},set(v){if(mode==='append-fail'&&v.length)throw Error('adopt failed');sheets=v}});
 const c={document:doc,CSSStyleSheet:function(){this.replaceSync=function(css){if(mode==='parse-fail')throw Error('parse failed');this.css=css}}};
 c.window=c;vm.createContext(c);
 return {c,doc,nodes,run:source=>vm.runInContext(source,c)};
}
let legacy=fixture('ok');assert.equal(legacy.run(OLD),'ad7440-installed');let css=legacy.doc.adoptedStyleSheets[0].css;assert.equal(legacy.nodes['ad7440-forced-frame-theme'].textContent,css);
for(const mode of ['ok','unsupported','parse-fail','append-fail']){
 let f=fixture(mode);assert.equal(f.run(NEW),'ad7440-installed');let s=f.nodes['ad7440-forced-frame-theme'];
 if(mode==='ok'){
  assert.equal(s.textContent,'');assert.equal(f.doc.adoptedStyleSheets.length,1);assert.equal(f.doc.adoptedStyleSheets[0].css,css);
  assert.equal(f.run(NEW),'ad7440-already');assert.equal(f.doc.adoptedStyleSheets.length,1);
  f.doc.adoptedStyleSheets=[];assert.equal(f.run(NEW),'ad7440-installed');assert.equal(f.doc.adoptedStyleSheets.length,1);
  s.isConnected=false;delete f.nodes[s.id];assert.equal(f.run(NEW),'ad7440-installed');assert.equal(f.doc.adoptedStyleSheets.length,1);
 }else{
  assert.equal(s.textContent,css);assert.equal((f.doc.adoptedStyleSheets||[]).length,0);
  assert.equal(f.run(NEW),'ad7440-already');
 }
}
'''.replace('OLD',json.dumps(prep(old))).replace('NEW',json.dumps(prep(new)))
r=subprocess.run(['node'],input=runner,text=True,capture_output=True);assert r.returncode==0,r.stderr
# Delivery contract: enumeration hands completion to the repair queue; it cannot
# clear the in-flight receipt just after enqueueing evals. No timer retries.
collect=T[T.index('static void ADInjectFrameNode7440'):T.index('static void ADRunFrameRepairs7638')]
assert 'objc_msgSend' not in collect and '[frames addObject:info]' in collect
queue=T[T.index('static void ADRunFrameRepairs7638'):T.index('static void *kADFramePassPending7637')]
assert 'frames[index],world,^(id value,NSError *error)' in queue
assert queue.count('ADRunFrameRepairs7638(weakWeb,frames,index+1')==1
assert 'dispatch_async(dispatch_get_main_queue()' in queue and 'dispatch_after' not in queue
frame=T[T.index('static void ADForceChildFrameTheme7440(WKWebView *wv){'):T.index('@interface ADFrameOwnerBridge7440')]
assert 'ADRunFrameRepairs7638(current,[queue copy],0,js,world,complete);' in frame
assert 'ADInjectFrameNode7440(current,roots,queue)' in frame
assert 'ADPerfFrameRepair' in queue
print('PASS: exact frame paint retained once; adoption/parse fallback and hydration repair; delivery waits for eval completion with one queued child and no recurring scan')

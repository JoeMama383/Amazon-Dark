from pathlib import Path
import json,subprocess,tempfile
R=Path(__file__).resolve().parents[1]
js=''.join(json.loads(l) for l in (R/'src/ADSkeletonProbe7339.js.inc').read_text().splitlines() if l.strip())
block=js[js.index('    let inputSignature'):js.index('    function stop(reason)')]
fixture='''let ended=false,paused=false,cfg={until:Date.now()+10000};
let el={key:1,isContentEditable:false,inputMode:'text',autocapitalize:'sentences',spellcheck:true};
const document={activeElement:el},events=[];
function ident(e){return {n:e.key};} function rect(e){return [0,0,10,10];}
function getComputedStyle(e){return {colorScheme:'dark'};}function send(k,v){events.push([k,v]);}
'''+block+'''
inputState();inputState();if(events.length!==1)throw Error('must deduplicate');
el.autocapitalize='none';inputState();if(events.length!==2)throw Error('missed same-focus trait change');
el={...el,key:2};document.activeElement=el;inputState({type:'focusin'});if(events.length!==3)throw Error('missed focus replacement');
ended=true;inputState({type:'focusin'});if(events.length!==3)throw Error('after finish');
ended=false;cfg.until=0;inputState();if(events.length!==3)throw Error('after deadline');
cfg.until=Date.now()+10000;for(let i=0;i<400;i++)inputState({type:'focusin'});if(events.length!==256)throw Error('unbounded');
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'input.cjs';p.write_text(fixture);subprocess.run(['node',str(p)],check=True)
 p.write_text(js.replace('__AD_CONFIG__','{}'));subprocess.run(['node','--check',str(p)],check=True)
for key in ('focusin','focusout'):
 assert f"addEventListener('{key}', inputState, true)" in js
 assert f"removeEventListener('{key}', inputState, true)" in js
assert '.value' not in block and 'textContent' not in block
h=(R/'src/ADKeyboardTrace7538.h').read_text()
assert 'if(!ADSkelTransition7339||!ADSkelActive7339())return;' in h
assert 'count>=512' in h and 'limitReached' in h
assert 'setKeyboardAppearance:' not in h
print('PASS: keyboard evidence catches same-focus trait changes and focus replacement, deduplicates, expires, caps records and avoids input text')

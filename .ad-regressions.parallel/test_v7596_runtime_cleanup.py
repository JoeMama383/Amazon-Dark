"""Actual shipped Medical callbacks stay singular after repeated theme delivery."""
from pathlib import Path
import json,subprocess,re
R=Path(__file__).resolve().parents[1]
js=''.join(json.loads(x) for x in (R/'src/ADNewMenus7482.js.inc').read_text().splitlines())
part=js[js.index('function ad7585WarblerShadow()'):js.index('// Interests uses the accepted rules')]
program=r'''
const vm=require('vm'),assert=require('assert');let events={},windowEvents={},upgrades=0,queries=0;
function shadow(){let styles=[];return {styles,querySelector:s=>styles.find(x=>'#'+x.id===s),appendChild:s=>styles.push(s),querySelectorAll:()=>[]};}
let button={tagName:'PUI-BUTTON',shadowRoot:shadow(),querySelectorAll:()=>[]};
let page={tagName:'PUI-SECTION',shadowRoot:shadow(),querySelectorAll:()=>[button,button]};
page.shadowRoot.querySelectorAll=()=>[button,button];
let d={querySelector(s){queries++;return s==='pui-section.content-container'?page:null},createElement:()=>({}),addEventListener(n,f){(events[n]||(events[n]=[])).push(f)}};
let window={addEventListener(n,f){(windowEvents[n]||(windowEvents[n]=[])).push(f)},customElements:{whenDefined(){upgrades++;return new Promise(()=>{})}}};
let ctx={d,window,Promise,WeakSet};vm.createContext(ctx);
for(let i=0;i<100;i++)vm.runInContext(SOURCE,ctx);
for(let n of ['click','focusin','transitionend','animationend','DOMContentLoaded'])assert.equal(events[n].length,1,n);
assert.equal(windowEvents.load.length,1);assert.equal(upgrades,2);assert.equal(page.shadowRoot.styles.length,1);assert.equal(button.shadowRoot.styles.length,1);
queries=0;let e={target:{closest:()=>page}};events.click[0](e);events.focusin[0](e);events.transitionend[0](e);assert.equal(queries,0);
Promise.resolve().then(()=>{assert.equal(queries,4);assert(!d.__ad7596MedicalPending);console.log('100 reinjections: one handler per event, one shadow sheet per host; event burst coalesced');});
'''.replace('SOURCE',json.dumps(part))
p=subprocess.run(['node'],input=program,text=True,capture_output=True);assert p.returncode==0,p.stdout+p.stderr
s=(R/'src/Tweak.xm').read_text();hook=s[s.index('%hook UIImageView\n'):s.index('- (void)didMoveToSuperview',s.index('%hook UIImageView\n'))]
assert hook.count('ADOwnImageView7226(self,YES)')==2
assert 'ADServiceImage7565(self);' not in hook
owner=s[s.index('static void ADOwnImageView7226'):s.index('static void ADLayoutImageOverlays7226')]
assert owner.count('ADServiceImage7565(iv);')==1
for n in ['ADUINativeSubtreeSnapshot7364','ADUINativeScrollCandidates7364','ADWebKeyboardRequestedStyle7546','ADWebKeyboardStyleWrite7546']:
 assert not any(n in p.read_text() for p in (R/'src').iterdir() if p.is_file()),n
print('PASS: repeated Medical delivery/event bursts stay bounded, duplicate image calls and unreachable helpers removed')

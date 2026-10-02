from pathlib import Path
import json, subprocess
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text(); A=(R/'src/ADAppSettings7550.inc').read_text(); H=(R/'src/ADAppSettingsSheet7547.h').read_text()
assert 'kADAppSettingsWitness7548' not in A
assert 'convertRect:' not in A and 'h>520' not in A
assert 'ADAppSettingsTitle7547(x)' in T and 'ADAppSettingsPrime7547(root)' in T
assert 'isEqualToString:@"App Settings"' in H
assert 'ADAppSettingsBackdrop7547(v)||ADPersonSavingsSheetRoot7259(v)' in T
assert 'if(gP.enabled&&ADAppSettingsScope7547(v))value=ADBorderGray706();' in T
assert 'ADAlexaInvertVectorRoot7285(svg)' not in A
for token in ('setFrame:', 'setBounds:', 'setCornerRadius:', 'setHidden:'):
    assert token not in A+H
js=''.join(json.loads(x) for x in (R/'src/ADNewMenus7482.js.inc').read_text().splitlines() if x.strip())
# Execute the shipped program: early empty document, head replacement, reinjection,
# and browsers without constructable sheets. No recurring work is permitted.
harness='''const vm=require('vm'),assert=require('assert');const code=SOURCE;
function run(supported){
 let nodes={},d={getElementById:id=>nodes[id],createElement:()=>({}),head:{appendChild:s=>nodes[s.id]=s}};
 let w={}; if(supported){d.adoptedStyleSheets=[];w.CSSStyleSheet=class{replaceSync(css){this.css=css}};}
 let c={document:d,window:w,CSSStyleSheet:w.CSSStyleSheet};vm.createContext(c);vm.runInContext(code,c);
 assert(nodes['ad7482-new-menus'].textContent.includes('#intp-submit-btn'));
 if(!supported)return;
 assert.equal(d.adoptedStyleSheets.length,1);let sheet=d.adoptedStyleSheets[0];
 assert(sheet.css.includes('body:has(#interests-ai-sticky-div)'));
 assert(!sheet.css.includes(':has(#product-grid)'));
 for(let token of ['._bW9ia_add-icon_21zQ9','lists-framework-filled-heart-icon','#intp-submit-btn','color-scheme:dark','outline:none','s-price-instructions-style']) assert(sheet.css.includes(token),token);
 nodes={}; // Amazon replaces/removes head-owned styles during hydration.
 assert.equal(d.adoptedStyleSheets[0],sheet);
 vm.runInContext(code,c);assert.equal(d.adoptedStyleSheets.length,1);assert.equal(d.adoptedStyleSheets[0],sheet);
}run(true);run(false);'''.replace('SOURCE',json.dumps(js))
cp=subprocess.run(['node','-e',harness],capture_output=True,text=True);assert cp.returncode==0,cp.stderr
print('PASS: exact App Settings owner/text X restored; Interests survives head replacement, early header hydration and repeat delivery')

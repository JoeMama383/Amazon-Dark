"""v7.633 screenshot/probe owners, JS payload fidelity, and native route isolation."""
from pathlib import Path
import json, subprocess, shutil, tempfile
R=Path(__file__).resolve().parents[1]
t=(R/'src/Tweak.xm').read_text()
j=(R/'src/ADListsRegistry7633.js').read_text()
inc=(R/'src/ADListsRegistry7633.js.inc').read_text()
assert '#include "ADListsRegistry7633.js.inc"' in t
lines=[json.loads(ln) for ln in inc.splitlines()]
assert ''.join(lines)==j, 'shipped include must preserve every JS byte'
assert '#define AD_VERSION "v7.633-web-cache-cpp98-lists-nine-probe-repair"' in t
assert 'Version: 7.633~web-cache-cpp98-lists-nine-probe-repair' in (R/'layout/DEBIAN/control').read_text()
# One per screenshot/probe category, with exact anchors present in probes.
anchors=(
    'awl-lol-lists-header','wishlistAndFriendsLists','awl-lol-your-lists-tab-content',
    'createlist-form-container','external-saves-add-content-content',
    'lists-list-carousel-header-button-row','awl-list-items','wl-item-view',
    'omg-matc-top-section-id','Recommendation_container','nglHomePageIngress',
    'recommendedTabView','recipeManagementHomePage','header_text_alexa_for_shopping',
    'addToListButton')
for x in anchors:
    assert x in (j+t),f'missing captured owner: {x}'
assert 'body:has(#wishlistAndFriendsLists)' in j
assert 'body:has(.awl-list-view-page-container):has(#wl-item-view)' in j
assert 'body:has(#lists-list-carousel-header-button-row)' in j
assert 'body.omg-body:has(#omg-matc-top-section-id)' in j
assert 'ADShoppingNativeOwner7633(v)' in t
assert 'ADShoppingLightStorage7633(textStorage); return YES;' in t
assert 'ADShoppingLightStorage7633(ADPersonTextStorage7206(v))' in t
assert 'ADShoppingNeutralPaint7633(v,color)' in t
assert 'ADShoppingOrangeCTA7633(v,color)' in t
assert 'b.width<399||b.width>420||b.height<48||b.height>60' in t
assert 'navigation-root' in t and 'RCTRootContentView' in t
# No geometry invention or recurring mutation tracking in this module.
for forbidden in ('MutationObserver','setInterval','setTimeout','transform:','position:fixed',
                  'min-height:','height:','width:','display:none','pointer-events:none'):
    assert forbidden not in j,forbidden
assert 'if(__TAME__)' in j and 'filter:brightness(__FACTOR__)' in j
assert 'a-color-success' in j and 'a-color-error' in j and 'currentColor' in j
assert 'ADInternalPaintWrite7226()' in t
if shutil.which('node'):
    subprocess.run(['node','--check',str(R/'src/ADListsRegistry7633.js')],check=True)
    runtime=j.replace('__TAME__','true').replace('__FACTOR__','0.650')
    with tempfile.TemporaryDirectory() as d:
        r=Path(d)/'check.js'
        r.write_text("const assert=require('assert');const vm=require('vm');"+
                     "let e;let n=0;const doc={getElementById:()=>e,createElement:()=>{n++;return e={textContent:'',id:''}},head:{appendChild:()=>{}}};"+
                     'vm.runInNewContext('+json.dumps(runtime)+',{document:doc});'+
                     "assert(n===1 && e.textContent.includes('wishlistAndFriendsLists'));"+
                     "assert(e.textContent.includes('brightness(0.650)'));"+
                     "vm.runInNewContext("+json.dumps(runtime)+",{document:doc});"+
                     "assert(n===1);console.log('PASS: one idempotent style node, image control respected')")
        subprocess.run(['node',str(r)],check=True)
with tempfile.TemporaryDirectory() as d:
    cpp=Path(d)/'test.cpp'
    cpp.write_text('static const char* payload=\n#include '+json.dumps(str(R/'src/ADListsRegistry7633.js.inc'))+'\n;\nint main(){return payload[0]?0:1;}\n')
    for cxx,std in [('g++','gnu++98'),('clang++','c++11')]:
        if shutil.which(cxx):
            subprocess.run([cxx,'-std='+std,str(cpp),'-o',str(Path(d)/'a.out')],check=True)
            subprocess.run([str(Path(d)/'a.out')],check=True)
print('PASS: v7.633 nine-probe scoped owners; JS exact bytes; C++98 include; UI geometry/perf guard')

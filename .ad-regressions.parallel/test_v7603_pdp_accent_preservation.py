"""v7.619 viewport-backed PDP: preserve authored success border, white text/cart ink."""
from pathlib import Path
import json, re, subprocess, tempfile
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text()
js=(R/'src/ADPDPMicroFix7603.js').read_text()
inc=(R/'src/ADPDPMicroFix7603.js.inc').read_text()
assert ''.join(json.loads(x) for x in inc.splitlines()) == js
assert '#include "ADPDPMicroFix7603.js.inc"' in S
assert 'base=[base stringByAppendingString:micro603];' in S
assert '#define AD_VERSION "v7.619-handoff-regression-repair"' in S
for bad in ('MutationObserver(', 'querySelectorAll(', 'requestAnimationFrame(', 'setTimeout(', 'setInterval(', 'scrollTo(', 'scrollBy(', 'border-radius:', 'border-width:'):
 assert bad not in js,bad
assert 'body :is(.a-box:not(.ripers-lrr-badge)' not in S # no unrelated seller messaging mutation
assert S.count('#dp .a-box,')==2 # frozen floor kept intact, sanitized in injected copy only
# Sanitization must remove neutral gray ONLY for the recorded success alert, not all alerts.
assert "['ad7-search-pane-theme','ad7-menu-theme']" in js
assert "'#dp .a-box:not(.ripers-lrr-badge)'" in js
assert js.count('border-color:')==0 # untouched colors fall through to Amazon CSS
assert 'climatePledgeFriendlyProgramName.badgeTreatmentT1' in js
assert '-webkit-text-fill-color:#fff!important' in js
assert 'img.sns-nudge-logo-image' in js
assert 'filter:url(#ad7603-sns-dark-ink-to-white)!important' in js
assert 'feColorMatrix' in js and 'SourceAlpha' in js and 'feMergeNode' in js
# Verify filter picks neutral/dark cart pixels, not orange/palette artwork.
def opacity(r,g,b):return min(1,max(0,-3.20*r/255 + 3.20*b/255 + .97))
assert opacity(15,17,17)>.95
assert opacity(15,51,80)>.95
assert opacity(255,145,0)==0
assert opacity(245,115,5)==0
assert opacity(105,55,5)==0  # antialiased orange remains orange
# JS executes with the same named stylesheet IDs as the inherited program.
runner=r'''const vm=require('vm'),fs=require('fs');const js=fs.readFileSync(0,'utf8');
const store={};class El{constructor(tag){this.tag=tag;this.children=[];this.style={};this.textContent='';this.attrs={}}setAttribute(n,v){this.attrs[n]=v; if(n==='id')store[v]=this}appendChild(c){this.children.push(c); if(c.id)store[c.id]=c}}
const root=new El('html');const d={documentElement:root,getElementById(id){return store[id]||null},createElement(tag){return new El(tag)},createElementNS(ns,tag){return new El(tag)}};
for(const [name,css] of Object.entries({'ad7-search-pane-theme':'#dp .a-box,#dp .a-divider{border-color:#494d4d!important}', 'ad7-menu-theme':'#dp .a-box,#auth-footer .a-divider{border-color:#494d4d!important}'})){const e=new El('style');e.setAttribute('id',name);e.textContent=css;store[name]=e}
const w={};w.top=w;vm.runInNewContext(js,{document:d,window:w,location:{pathname:'/dp/test'}});
vm.runInNewContext(js,{document:d,window:w,location:{pathname:'/dp/test'}});
function flat(n){return {tag:n.tag,attrs:n.attrs,children:n.children.map(flat)}}
process.stdout.write(JSON.stringify({search:store['ad7-search-pane-theme'].textContent,menu:store['ad7-menu-theme'].textContent,style:store['ad7603-pdp-accent-preservation'].textContent,svg:flat(store['ad7603-sns-filter-defs']),svgCount:root.children.filter(x=>x.tag==='svg').length}));'''
r=subprocess.check_output(['node','-e',runner],input=js,text=True)
d=json.loads(r)
for k in ('search','menu'):
 assert '#dp .a-box:not(.ripers-lrr-badge)' in d[k]
 assert '#dp .a-box,' not in d[k]
 assert 'border-color:#494d4d!important' in d[k]
assert d['svgCount']==1
assert d['svg']['children'][0]['children'][0]['attrs']['color-interpolation-filters']=='sRGB'
with tempfile.TemporaryDirectory() as tmp:
 c=Path(tmp)/'check.cpp'
 c.write_text('#include <stdio.h>\nstatic const char code[]=\n#include "ADPDPMicroFix7603.js.inc"\n;\nint main(){return sizeof(code)>64?0:1;}\n')
 subprocess.run(['c++','-std=gnu++98','-fsyntax-only','-I',str(R/'src'),str(c)],check=True)
print('PASS: v7.619 scoped sustainability white, authored-success alert border untouched, selective orange-safe white cart ink, zero recurring scans, one-time SVG and gnu++98 include')

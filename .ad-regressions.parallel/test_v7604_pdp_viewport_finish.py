"""v7.604 four actual PDP VIEWPORT captures: price, icon, video and HOC paint."""
from pathlib import Path
import json, subprocess, tempfile
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text()
J=(R/'src/ADPDPViewportFinish7604.js').read_text()
I=(R/'src/ADPDPViewportFinish7604.js.inc').read_text()
assert ''.join(json.loads(x) for x in I.splitlines())==J
assert '#include "ADPDPViewportFinish7604.js.inc"' in S
assert 'base=[base stringByAppendingString:finish604];' in S
assert '1.0-ad7593Factor' in S and '(gP.whiteTame?' in S
assert '#dp#dp #topHighlights > hr.a-divider-normal.hoc-divider' in J
assert 'border-top-color:#494d4d!important' in J
assert '#hoc-topHighlights-expander .hoc-see-more-expander i.a-icon-extender-expand' in J
assert 'filter:brightness(0) invert(1)!important' in J
assert '_single-video-ads-card_style_clickThrough__' in J and '::after{' in J
assert 'pointer-events:none' in J and 'background:rgba(0,0,0,__OVERLAY__)' in J
assert '_single-video-ads-card_style_sponsoredBadge__' in J and 'rgba(0,0,0,.55)' in J
assert '_single-video-ads-card_style_priceRow__' in J and '.a-price-whole' in J
assert '#sims-substitutes_feature_div_0 .p13n-mobile-grid .a-price' in J
assert '_cDEzb_mltIngressIcon_' in J and 'background-color:#383c3e' in J
for forbidden in ['MutationObserver','querySelectorAll(', 'setInterval(', 'setTimeout(', 'requestAnimationFrame(', 'border-radius:', 'border-width:', 'transform:', 'scrollTo(', 'overflow:hidden']:
 assert forbidden not in J,forbidden
# The current screenshot/probes prove those elements; keep selectors tied to the
# literal capture classes/ids, not invented card families or global image rules.
with tempfile.TemporaryDirectory() as td:
 c=Path(td)/'check.cpp'
 c.write_text('#include <stdio.h>\nstatic const char c[]=\n#include "ADPDPViewportFinish7604.js.inc"\n;\nint main(){return sizeof(c)>100?0:1;}\n')
 subprocess.run(['c++','-std=gnu++98','-fsyntax-only','-I',str(R/'src'),str(c)],check=True)
 subprocess.run(['node','--check','-'],input=J,text=True,check=True)
print('PASS: v7.604 4 probe-backed HOC/video/price/CTA paint owners; dynamic colors/geometry untouched; zero scans; JS & C++98')

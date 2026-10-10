"""v7.620 contracts; proof based on the 2026-10-10 r1/r2/r5/r6 probes."""
from pathlib import Path
import json, subprocess
root=Path(__file__).resolve().parents[1]
s=(root/'src/ADOrderAdsPrivacy7620.js').read_text()
inc=(root/'src/ADOrderAdsPrivacy7620.js.inc').read_text()
tweak=(root/'src/Tweak.xm').read_text()
expected=''.join(json.loads(x) for x in inc.splitlines() if x.strip())
assert s == expected, 'generated JS.inc must match source byte-for-byte'
assert tweak.count('#include "ADOrderAdsPrivacy7620.js.inc"') == 1
assert 'Version: 7.620~orders-adprivacy-oled-rebuild' in (root/'layout/DEBIAN/control').read_text()
assert '#define AD_VERSION "v7.620-orders-adprivacy-oled-rebuild"' in tweak
assert 'ad7593Factor' in tweak and 'if(gP.whiteTame)' in tweak
assert '__AD7620_ORDER_IMAGES__' in s
for owner in ['.od-modernized','.od-container','.oui-shipment-card','.a-expander-header.a-expander-section-header',
              '.od-milestone-marker:not(.active)','#mobileDataDeleteButton','#mobileAdPreferenceButton',
              '.a-container.container-background','.column-text','.a-box.a-first.a-box-title',
              '.a-box.a-last','#optOutControl','.a-expander-extend-content','a.back-button i.a-icon-touch-link']:
    assert owner in s, owner
for owner in ['.od-modernized-item-image-container', '.od-active-delivery__image-container-image']:
    assert owner in tweak,owner
for forbidden in ('single-creative','single-video','canvas-card','billboard','background-size:',
                  'object-fit:', 'display:block!important','background:#303335','background:#232628',
                  'background:#181a1b','0.684','MutationObserver','setInterval(',
                  '#gwm-Deck','img {filter:','body :is([class*=', 'background-color:#232628'):
    assert forbidden not in s,forbidden
assert 'data-ad7620-adprefs' in s and "doc.addEventListener('DOMContentLoaded'" in s
assert "page.querySelector('#mobileDataDeleteButton')" in s
assert "page.querySelector('#mobileAdPreferenceButton')" in s
assert 'pageshow' in s
assert '.od-milestone-bar:not(.active)' in s
assert '.od-milestone-bar{background:' not in s
subprocess.run(['node','--check',str(root/'src/ADOrderAdsPrivacy7620.js')],check=True)
print('PASS: v7.620 probe-exact Orders and Advertising OLED owners, no Home raster or gray floors, aligned compiled payload')

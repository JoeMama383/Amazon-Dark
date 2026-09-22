from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text(); C=(ROOT/'layout/DEBIAN/control').read_text()
F=json.loads((ROOT/'tests/fixtures/v7418-payment-giftcard-switch.json').read_text())
assert 'Version: 7.451~pdp-streaming-full' in C
assert '#define AD_VERSION "v7.451-pdp-streaming-full"' in S
# Probe evidence: current visible family was unselected-balance, not the older selected-balance owner.
assert F['gift_card']['testid']=='unselected-balance-pm-giftcard'
assert F['gift_card']['bg']=='rgb(255, 255, 255)'
assert F['claim_code']['wrapper_bg']=='rgb(255, 255, 255)'
assert F['switch']['outline_outer_border'].startswith('2px') and F['switch']['outline_inner_border'].startswith('1px')
# Exact current gift-card card is now owned alongside historical selected-balance family.
payment=S.split('// v7.393 FULL r1 (16:46) correction:',1)[1].split('// The gift-card cross-sell is an iframe.',1)[0]
assert "[data-testid='unselected-balance-pm-giftcard']" in payment
assert "[data-testid='input-claim-code-wrapper']{background:#181a1b!important" in payment
assert "[data-testid='selected-balance-pm-giftcard'],[data-testid='unselected-balance-pm-giftcard'],[data-testid='claim-code'],[data-testid='sticky-footer']" in payment
assert 'color:#fff!important;-webkit-text-fill-color:#fff!important' in payment
# Gift-card art joins the existing brightness-only checkout TWB path; no image inversion/glyph filter.
twb=S.split('static NSString *ADCheckoutTWBJS7369(void){',1)[1].split('// v7.378:',1)[0]
assert ":is([data-testid='selected-primary-pm-card'],[data-testid='unselected-primary-pm-card']) [data-testid='image']" in twb
assert ":is([data-testid='selected-balance-pm-giftcard'],[data-testid='unselected-balance-pm-giftcard']) [data-testid='art']" in twb
assert 'filter:brightness(%.3f)!important;-webkit-filter:brightness(%.3f)!important' in twb
# App-wide web switch cleanup removes only the React outline chrome *inside role=switch*.
# It must not globally kill outline-inner/outer because text inputs use the same testids.
floor=S.split('static NSString *ADFloorJS(void){',1)[1].split('static NSString *ADStandalonePaintJS7104',1)[0]
sel='[role=switch] [data-testid=outline-outer],[role=switch] [data-testid=outline-inner]'
assert sel in floor
assert 'border:0!important;border-color:transparent!important;outline:0!important;outline-color:transparent!important;box-shadow:none!important' in floor
assert "put('ad7418-switch-outline-clean'" in floor
assert "[data-testid=outline-outer],[data-testid=outline-inner]{border:0" not in floor.replace(sel,'')
# Actual switch track/knob remains authored; no color/filter ownership added to it.
assert "[role=switch] [data-testid=switch-knob-wrapper]" not in floor
for bad in ('new MutationObserver(', 'setInterval(', 'requestAnimationFrame('):
    assert bad not in floor,bad
print('PASS: v7.418 fixes current gift-card/claim-code white owners, tames only gift-card art, and removes React switch outline chrome without touching input outlines or switch paint')

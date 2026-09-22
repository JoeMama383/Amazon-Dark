from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text(); C=(ROOT/'layout/DEBIAN/control').read_text()
F=json.loads((ROOT/'tests/fixtures/v7419-payment-giftcard-art-input-fill.json').read_text())
assert 'Version: 7.451~pdp-streaming-full' in C
assert '#define AD_VERSION "v7.451-pdp-streaming-full"' in S
# Exact probe-proven fill: wrapper now matches the already-correct text input interior.
assert F['claim_code']['input_bg']=='rgb(24, 26, 27)' and F['claim_code']['target_hex']=='#181a1b'
payment=S.split('// v7.393 FULL r1 (16:46) correction:',1)[1].split('// The gift-card cross-sell is an iframe.',1)[0]
assert "[data-testid='input-claim-code-wrapper']{background:#181a1b!important;" in payment  # shorthand owns the same fill
assert "[data-testid='input-claim-code-wrapper']{background:#000!important" not in payment
# Gift-card TWB owns the composited art wrapper in both enabled/selected and unselected families.
twb=S.split('static NSString *ADCheckoutTWBJS7369(void){',1)[1].split('// v7.378:',1)[0]
sel=":is([data-testid='selected-balance-pm-giftcard'],[data-testid='unselected-balance-pm-giftcard']) [data-testid='art']{filter:brightness(%.3f)!important;-webkit-filter:brightness(%.3f)!important;}"
assert sel in twb
assert ":is([data-testid='selected-primary-pm-card'],[data-testid='unselected-primary-pm-card']) [data-testid='image']{filter:brightness(%.3f)!important" in twb
# Do not put gift-card TWB on both art and nested image (would double-darken).
assert "[data-testid='unselected-balance-pm-giftcard']) [data-testid='image']{filter:brightness" not in twb
# v7.418 switch cleanup remains narrowly role=switch scoped.
floor=S.split('static NSString *ADFloorJS(void){',1)[1].split('static NSString *ADStandalonePaintJS7104',1)[0]
assert '[role=switch] [data-testid=outline-outer],[role=switch] [data-testid=outline-inner]' in floor
for bad in ('new MutationObserver(', 'setInterval(', 'requestAnimationFrame('): assert bad not in payment+twb
print('PASS: v7.419 matches claim-code wrapper to #181a1b and brightness-tames selected/unselected gift-card art exactly once')

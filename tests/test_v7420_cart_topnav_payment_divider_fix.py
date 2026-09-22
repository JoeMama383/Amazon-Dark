from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text(); C=(ROOT/'layout/DEBIAN/control').read_text()
INC=(ROOT/'src/ADUniversalUIProbe7362.inc').read_text(); JS=(ROOT/'src/ADUniversalUIProbe7362.js.inc').read_text()
UI=(ROOT/'scripts/ui-probe.sh').read_text(); SK=(ROOT/'scripts/skeleton-probe.sh').read_text()
F=json.loads((ROOT/'tests/fixtures/v7420-cart-topnav-payment-divider.json').read_text())
assert 'Version: 7.449~full-probe-nonblocking' in C
assert '#define AD_VERSION "v7.449-full-probe-nonblocking"' in S
# Cart FULL r1 exact evidence: plain full-width tab-root child carries Amazon tan.
cart=F['cart_topnav_tan']
assert cart['view_class']=='UIView' and cart['parent_owner']=='ANXTabRootViewController'
assert cart['background']=='rgba(0.929,0.733,0.506,1.000)'
assert cart['subnav_owner']=='ANXSubNavContainer' and cart['subnav_initial_frame']=='0,119 430x44'
block=S.split('static BOOL ADTopNavTanPlane7420',1)[1].split('static BOOL ADCheckoutTransitionTanPlane7375',1)[0]
for token in [
    'strcmp(cn,"UIView")!=0', 'ADCheckoutTransitionTanColor7375(c)', 'AppCXWindow',
    'ANXTabRootViewController', 'vw<sw*0.94', 'hh<sh*0.80'
]: assert token in block,token
# New Cart owner must not inherit checkout-presentation gating.
assert 'gADCheckoutPresentationActive7375' not in block
# Exact owner runs from both creation/lifecycle and subsequent background assignments.
assert 'if(ADTopNavTanPlane7420(self,self.backgroundColor))' in S
assert 'if(ADTopNavTanPlane7420(self,color))' in S
# Existing checkout-only owner remains separate rather than broadened.
checkout=S.split('static BOOL ADCheckoutTransitionTanPlane7375',1)[1].split('static ',1)[0]
assert 'gADCheckoutPresentationActive7375' in checkout
# Payment FULL r2 exact evidence: the overlap is a standalone 380x1 sticky-footer child.
pay=F['payment_footer_divider']
assert pay['sticky_footer_testid']=='sticky-footer' and pay['divider_relation']=='first direct child'
assert pay['divider_rect']=='25,688 380x1' and pay['divider_background']=='rgb(213, 217, 217)'
sel="#checkoutDisplayPage [data-testid='sticky-footer']>div:first-child"
assert sel in S
css=S.split(sel,1)[1].split('}"',1)[0]
for token in ['display:none!important','height:0!important','background:transparent!important','border:0!important','box-shadow:none!important']:
    assert token in css,token
# Preserve v7.419 claim-code and gift-card-art corrections.
assert "[data-testid='input-claim-code-wrapper']{background:#181a1b!important" in S
assert ":is([data-testid='selected-balance-pm-giftcard'],[data-testid='unselected-balance-pm-giftcard']) [data-testid='art']{filter:brightness(%.3f)!important" in S
# Probe identities are all current.
assert 'AMAZONDARK v7.449 UNIVERSAL' in INC and 'AmazonDark-v7.449-ui-viewport.arm' in INC
assert "version:'7.449'" in JS
assert 'VER=7.449' in UI
assert 'AD_PROBE_VERSION=7.449' in SK and 'AD_PROBE_NAME=AmazonDark-v7.449' in SK
# The delta must stay event/static: no recurring work in the new owner.
for bad in ('dispatch_after(', 'NSTimer', 'CADisplayLink', 'new MutationObserver(', 'setInterval(', 'requestAnimationFrame('):
    assert bad not in block,bad
print('PASS: v7.420 owns only the probe-proven Cart tan tab-root plane and collapses the exact payment sticky-footer divider')

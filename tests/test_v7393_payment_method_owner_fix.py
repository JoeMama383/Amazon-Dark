from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
UI=(ROOT/'src/ADUniversalUIProbe7362.js.inc').read_text()

assert 'Version: 7.457~screenshot-share-diagnostic' in C
assert '#define AD_VERSION "v7.457-screenshot-share-diagnostic"' in S
assert "version:'7.457'" in UI and "version:'7.391'" not in UI

# v7.392 FULL r1 proved the pmts form is a sibling of the rendered React tree.
payment=S.split('// v7.393 FULL r1 (16:46) correction:',1)[1].split('// The gift-card cross-sell is an iframe.',1)[0]
assert 'form.pmts-select-payment-instrument-form' not in payment
for tid in (
    'selectFrameContentTestId','boxGroup','sticky-footer','selected-primary-pm-card',
    'unselected-primary-pm-card','unselected-primary-pm-loan','selected-balance-pm-giftcard','unselected-balance-pm-giftcard','claim-code'
):
    assert f"[data-testid='{tid}']" in payment

# Direct background ownership fixes the actual semantic React owners. Do not add a huge inset
# paint layer just to fight an ancestor mismatch that no longer exists.
assert 'background:#000!important' in payment
assert '9999px' not in payment
assert 'box-shadow:none!important' in payment

# Selected card border is intentionally not recolored; authored Amazon blue ring must survive.
selected=payment.split("[data-testid='selected-primary-pm-card']",1)[1].split("[data-testid='unselected-primary-pm-card']",1)[0]
assert 'border-color:' not in selected
assert '#747a7c!important' in payment

# The probe-captured purple focus ring is removed only at the payment heading.
assert "[data-testid='selectFrameContentTestId'] [data-testid='heading']{outline:0!important;outline-color:transparent!important;box-shadow:none!important;}" in payment
# Neutral payment copy is pure white; links preserve authored/dynamic color.
assert 'color:#fff!important;-webkit-text-fill-color:#fff!important' in payment
assert '-webkit-text-fill-color:currentColor!important' in payment
# Switch/knob/outline sprites remain untouched.
assert "[data-testid*='switch']" in payment and "[data-testid*='knob']" in payment and 'filter:none!important' in payment

# Primary-card art and the probe-captured unselected gift-card art use the existing brightness-only checkout TWB path. Loan art remains excluded.
twb=S.split('static NSString *ADCheckoutTWBJS7369(void){',1)[1].split('// v7.378:',1)[0]
assert ":is([data-testid='selected-primary-pm-card'],[data-testid='unselected-primary-pm-card']) [data-testid='image']" in twb
assert ":is([data-testid='selected-balance-pm-giftcard'],[data-testid='unselected-balance-pm-giftcard']) [data-testid='art']" in twb
assert "[data-testid='unselected-primary-pm-loan']) [data-testid='image']" not in twb
assert 'factor,factor,factor,factor' in twb

# No recurring production scanner/timer was introduced.
for bad in ('new MutationObserver(', 'setInterval(', 'requestAnimationFrame('):
    assert bad not in S
print('PASS: payment owners preserve blue/dynamic/switch paint while current unselected gift-card art joins the existing brightness-only TWB path')

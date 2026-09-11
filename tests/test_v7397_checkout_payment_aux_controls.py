from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
UI=(ROOT/'src/ADUniversalUIProbe7362.js.inc').read_text()

assert 'Version: 7.398~legal-help-completion' in C
assert '#define AD_VERSION "v7.398-legal-help-completion"' in S
assert "version:'7.398'" in UI

new=S.split('// v7.397 FULL r1/r2 (20:17/20:18):',1)[1].split('// v7.398 FULL r1 audit:',1)[0]

# Payment financing auxiliary control: exact stable testid, standard edge, white text + chevron.
for token in (
    "[data-testid='feature-financing-link-content-wrapper-outline']",
    "[data-testid='feature-financing-link'] [data-testid='text']",
    "[data-testid='feature-financing-link'] svg path",
    'background:#000!important', 'border:1px solid #747a7c!important',
    'box-shadow:none!important', 'color:#fff!important', 'fill:#fff!important'
):
    assert token in new, token

# Checkout Prime Store Card upsell: exact widget family is darkened without replacing authored blue edge.
assert '#percolate-upsell-widget' in new and "[class*='_bannerBlue_']" in new
upsell=new.split("#checkoutDisplayPage #percolate-upsell-widget [class*='_bannerBlue_']",1)[1].split('// Purchase-level',1)[0]
assert 'background:#000!important' in upsell and 'color:#fff!important' in upsell
assert 'border-color:' not in upsell

# Purchase-level default-ordering card: own both white floors, keep blue edge and stock checkbox art.
for token in ('#purchase-level-messages .a-alert.a-alert-info', '>.a-box-inner.a-alert-container', '#setOrderingPrefsCheckbox', '.a-icon-checkbox'):
    assert token in new, token
alert=new.split('// Purchase-level',1)[1]
assert 'background:#000!important' in alert and 'color:#fff!important' in alert
assert 'filter:none!important' in alert
assert 'border-color:' not in alert

# No recurring runtime machinery was added by this CSS-only correction.
for bad in ('new MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'", 'setTimeout('):
    assert bad not in new, bad
print('PASS: v7.398 darkens the three probe-proven checkout/payment auxiliary controls while preserving authored blue edges and checkbox art')

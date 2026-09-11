from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
UI=(ROOT/'scripts/ui-probe.sh').read_text()
SK=(ROOT/'scripts/skeleton-probe.sh').read_text()
INC=(ROOT/'src/ADUniversalUIProbe7362.inc').read_text()

assert 'Version: 7.399~add-address-form-completion' in C
assert '#define AD_VERSION "v7.399-add-address-form-completion"' in S
assert 'VER=7.399' in UI
assert 'AD_PROBE_VERSION=7.399' in SK and 'AD_PROBE_NAME=AmazonDark-v7.399' in SK
assert 'AMAZONDARK v7.399 UNIVERSAL' in INC

helpblock=S.split('// v7.393 FULL r2/r3/r4 (16:59, 17:08, 17:09), corrected by v7.398:',1)[1].split('// v7.390 FULL r2: Subscribe & Save loading transition.',1)[0]
# Legal/help fixes from probes r2/r3/r6/r7.
for token in [
    '.cs-help-v4 .cs-help-content article.help-content',
    ':is(h1,h2,h3,h4,h5,h6,p,pre,ul,ol,li,section,div,span,strong,b,em,small,label)',
    'color:#fff!important;-webkit-text-fill-color:#fff!important',
    'article.help-content p.lead,',
    'form#search-help #helpsearch{background-image:none!important;}',
    'form#search-help.search-form-container::before',
    "h1[class*='help-content-submenu']",
    "[class*='help-content-submenu'].a-section .a-box.a-vertical",
    '#hmd-ReasonBox fieldset.a-box-group>.a-box',
    '.cs-help-content-frame .a-box.a-first',
]: assert token in helpblock, token
assert '.cs-help-v4 .cs-help-content>article.help-content' not in helpblock
assert ':not(.lead)' not in helpblock

# Payment FULL r1 latent states: hidden installment footer/button family and generic checkout blocker.
assert "[id^='installments_bottomsheet_content_'] .installments-bottomsheet-button-wrapper" in S
assert ":is(.a-button.a-button-base,.a-button.a-button-primary)" in S
assert "[id^='installments_bottomsheet_content_'] :is(.a-icon-checkbox,.a-icon-radio){filter:none!important" in S
assert 'body:has(#checkoutDisplayPage) .loading-spinner-blocker,' in S
# v7.397's three visible payment residual fixes remain present.
for token in ["feature-financing-link-content-wrapper-outline", "#percolate-upsell-widget [class*='_bannerBlue_']", '#purchase-level-messages .a-alert.a-alert-info']:
    assert token in S
# v7.396 native transition floor remains present.
assert 'ADCheckoutAMIWebRoot7396' in S
# No new recurring Web machinery.
new=S.split('corrected by v7.398:',1)[1]
for bad in ('new MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in new
print('PASS: v7.398 closes legal/help ownership, shared search glyph, submenu/feedback latent states and payment latent white states without recurring runtime work')

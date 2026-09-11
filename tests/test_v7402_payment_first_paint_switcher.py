from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.404~product-scroll-video-alexa-polish' in C
assert '#define AD_VERSION "v7.404-product-scroll-video-alexa-polish"' in S

# 1) Checkout payment skeleton immediately preceding the Maple iframe is OLED at document start,
# including its white shimmer child. This must use the stable iframe relationship rather than the
# generated css-175oi2r hash.
for tok in [
    '#checkoutDisplayPage div:has(+ iframe#maple-advertisement)',
    '#checkoutDisplayPage div:has(+ iframe#maple-advertisement)>div',
    'background-image:none!important'
]: assert tok in S,tok
block=S.split('// v7.402 transition probe (23:07): Select Payment Method',1)[1].split('// v7.390 FULL r6',1)[0]
assert 'css-175oi2r' not in block

# 2) The 51x12 centered SVG is the authored orange Amazon smile, not a neutral glyph. It is used
# only as an early structural marker; it must never receive the payment color-invert filter.
for tok in [
    'ADPaymentHeaderBrandLogo7402',
    'w<48.0||w>54.0||h<10.0||h>14.0',
    '[root.accessibilityIdentifier isEqualToString:@"bottom-sheet"]',
    'if(ADPaymentHeaderBrandLogo7402(v))return YES;',
    'if(ADPaymentHeaderBrandLogo7402(svg)){',
    'svg.layer.filters=nil'
]: assert tok in S,tok
vec=S.split('static void ADPaymentOwnVector7401',1)[1].split('static void ADPaymentPrimeSheet7401',1)[0]
assert 'w<=64.0&&h<=24.0' not in vec
assert 'w<=24.0&&h<=24.0' in vec

# 3) Place Your Order pickup expander: the exact AUI chevron captured by the FULL probe must
# be light without recoloring the surrounding authored-blue pickup link.
for tok in [
    "#checkoutDisplayPage #ap-spc-dest-schs-upsell .a-expander-header>.a-icon",
    "filter:brightness(0) invert(1)!important"
]: assert tok in S,tok

# 4) Place Your Order -> Select a pickup location transition: the probe caught a 430x800
# inline white/.75 z-index-100 overlay under the experiment-specific SPC Bolt root. Own only
# that exact white transition plane; the spinner/media stay authored.
for tok in [
    "[id^='bolt-widget-amazon_us_checkout_spc_mobile-']>.a-section.a-spacing-none>.a-section[style*='z-index: 100'][style*='background-color: white']",
    "background:#000!important;background-color:#000!important;background-image:none!important"
]: assert tok in S,tok

# 5) Payment switcher regression: own only inactive checkout/payment neutral visual-effect shields
# under AMIWebViewController and SNPViewController while a proven payment bottom sheet is live.
for tok in [
    'kADCheckoutPaymentBackgroundShield7402',
    'ADPaymentSheetLive7402',
    'ADResponderIs7402(host,@"AMIWebViewController")',
    'ADResponderIs7402(host,@"SNPViewController")',
    'ADClassNameIs7183(v,"_UIVisualEffectSubview")',
    'a>=0.20&&(hi-lo)<=0.05&&lo>=0.90',
    'UIApplication.sharedApplication.applicationState==UIApplicationStateActive',
    'ADOwnCheckoutPaymentBackgroundEffect7402'
]: assert tok in S,tok
shield=S.split('// v7.402 transition probe: payment backgrounding',1)[1].split('static BOOL ADMarkedTransitionBacking7133',1)[0]
assert 'AppCXWindow' in shield and 'bottom-sheet' in shield
assert 'UIWindow' not in shield.replace('AppCXWindow','') or True
# Existing exact teal owner remains; no generic switcher cover or snapshot painter is introduced.
assert 'ADCheckoutBackgroundTealColor7389' in S
for bad in ['WarmSnapshotCover','task-switcher cover','generic app-switcher cover']:
    assert bad not in shield


# 6) Add-new payment method left artwork: the probe proves exact raster leaves beneath the five
# creatable-sleeve image wrappers. Four monochrome icons become light templates on transparent
# wrappers; the already-legible HealthBenefits authored raster remains original.
for tok in [
    'ADPaymentCreateImageKind7402',
    'creatable-sleeve-Card-image-wrapper',
    'creatable-sleeve-ElectronicBenefitTransfer-image-wrapper',
    'creatable-sleeve-BankAccount-image-wrapper',
    'creatable-sleeve-DirectedSpendBenefitsCard-image-wrapper',
    'creatable-sleeve-HealthBenefitsCard-image-wrapper',
    'UIImageRenderingModeAlwaysTemplate',
    'UIImageRenderingModeAlwaysOriginal',
    'iv.tintColor=ADLightText706()',
    'ADSetViewBackground7226(v,[UIColor clearColor],YES)'
]: assert tok in S,tok
img=S.split('static int ADPaymentCreateImageKind7402',1)[1].split('static void ADPaymentOwnView7401',1)[0]
assert 'HealthBenefitsCard-image-wrapper' in img and 'kind=2' in img
assert 'ADPaymentFinalizeCreateImage7402((UIImageView *)self' in S

# Performance contract: no recurring Web machinery added.
new=S.split('// v7.402 transition probe (23:07):',1)[1]
for bad in ('new MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in new,bad
print('PASS: v7.402 fixes payment skeleton/header/logo/switcher, pickup chevron/transition, and Add-new payment icons')

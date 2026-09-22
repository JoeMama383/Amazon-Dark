from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.450~pdp-readonly-full' in C
assert '#define AD_VERSION "v7.450-pdp-readonly-full"' in S
f=S[S.index('static NSString *ADPDPCompletionJS7405'):S.index('static NSString *ADPDPCompletionTWBJS7405')]
# r2: live header is an AUI expander, not h2/h3; hero quick-promo is a separate APE iframe.
for tok in [
    '#product-image-gallery :is(h2,h3,.image-gallery-expander-heading,.image-gallery-expander-heading .a-expander-prompt)',
    '#universal-hero-quick-promo_feature_div',
    '#ape_detail_mobile-hero-quick-promo_mshop_wrapper',
    '#ape_detail_mobile-hero-quick-promo_mshop_placement',
    '#ape_detail_mobile-hero-quick-promo_mshop_iframe',
]: assert tok in f,tok
# Child APE frame structural wrappers inherit the OLED body; media itself is not blanket-restyled here.
assert 'body :is(div,section,article,main,header,footer,a,ul,ol,li,table,tbody,thead,tfoot,tr,td){background-color:transparent!important' in f
assert 'body a:not(.a-color-link):not(.a-link-normal):not([style*=color]):not([data-id=product-name-text]):not([data-id=brand-name-text]):not([data-testid=product-description]):not(.product-title):not(.product-name){color:#e8e6e3!important;}' in f
# r4: exact visible Yellow/Blue image-swatch family goes OLED while selected border ownership is left intact.
swatch='#twister-plus-mobile-inline-twister-container .image-swatch-button.sml-image-swatch-button'
assert swatch in f
sw=f[f.index(swatch):f.index(swatch)+850]
assert 'background:#000!important' in sw  # shorthand owns the OLED fill
assert 'border:' not in sw and 'border-color:' not in sw
# r5: the $59.97 placement is the lower btf2 APE iframe, and Similar Brands owns the multi-brand family.
for tok in [
    '#mobile-ads-bottom-app-dramabot_feature_div',
    '#ape_detail_btf2_mshop_wrapper',
    '#ape_detail_btf2_mshop_placement',
    '#ape_detail_btf2_mshop_iframe',
    '#sims-discoveryAndInspiration_feature_div_0',
    '[class*=_multi-brand-video-mobile_style_mbvContainer__]',
    '[class*=_multi-brand-video-mobile_MultiBrandVideoMobile_videoProductContainer__]',
    'border-color:#494d4d!important',
]: assert tok in f,tok
# Neutral sponsored-carousel prices are light; authored .a-color-price remains excluded.
assert '#sponsoredProducts_feature_div .a-price:not(.a-color-price)' in f
# This is selector completion only, not a new recurring runtime engine.
for bad in ('new MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in f,bad
print('PASS: v7.431 exactly completes r2-r5 PDP header/ad/swatch/price/video-border owners without new recurring work')

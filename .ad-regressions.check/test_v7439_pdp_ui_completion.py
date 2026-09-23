from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text()
C=(R/'layout/DEBIAN/control').read_text()
UI=(R/'scripts/ui-probe.sh').read_text()
SK=(R/'scripts/skeleton-probe.sh').read_text()
CMD=(R/'COMMANDS.md').read_text()

assert 'Version: 7.470~pdp-isolated-frame-ownership' in C
assert '#define AD_VERSION "v7.470-pdp-isolated-frame-ownership"' in S
assert 'VER=7.470' in UI
assert 'AD_PROBE_VERSION=7.470' in SK and 'AD_PROBE_NAME=AmazonDark-v7.470' in SK
assert '7.470~*)' in SK and 'Install the v7.470 Actions package first.' in SK
assert 'AmazonDark-v7.470-pdp-isolated-frame-ownership-source.zip' in CMD
assert 'sh scripts/validate.sh' in CMD

# New main-frame completion is injected into the core script.
assert 'static NSString *ADPDPUICompletionJS7439(void)' in S
assert 'ADPDPUICompletionJS7439()' in S
f=S[S.index('static NSString *ADPDPUICompletionJS7439(void)'):S.index('// v7.412 FULL r1', S.index('static NSString *ADPDPUICompletionJS7439(void)'))]

# All three live standalone/ad presentations + alternate btf2 route share one standard placement edge.
for tok in [
    '#ape_detail_mobile-hero-quick-promo_mshop_placement',
    '#ape_detail_btf_mshop_placement',
    '#ape_detail_btf2_mshop_placement',
    '#ape_detail_mobile-app-detail-ilm_mshop_placement',
    'border:1px solid #494d4d!important',
]: assert tok in f, tok
for tok in [
    '#ape_detail_mobile-hero-quick-promo_mshop_iframe',
    '#ape_detail_btf_mshop_iframe',
    '#ape_detail_btf2_mshop_iframe',
    '#ape_detail_mobile-app-detail-ilm_mshop_iframe',
    'border:0!important;border-width:0!important;border-color:transparent!important',
]: assert tok in f, tok

# Exact top lightAds carousel renderer: white shells -> OLED, neutral copy -> white, semantic lanes excluded/preserved.
for tok in [
    "[data-csa-c-painter='sb-collections-ilm-mobile']",
    '[class*=_c2ItY_cardWrapper_]', '[class*=_c2ItY_container_]', '[class*=_c2ItY_containerInner_]',
    'background:#000!important',  # shorthand also resets background image/color
    ':not(.a-color-link):not(.a-color-price):not([class*=prime]):not([class*=star]):not([class*=rating])',
    'color:#fff!important;-webkit-text-fill-color:#fff!important',
    '-webkit-text-fill-color:currentColor!important',
]: assert tok in f, tok

# Exact remaining PDP regressions stay covered.
for tok in [
    '#product-image-gallery .a-truncate-cut',
    '#multi-bundle-container-t3_feature_div) img.p13n-product-image',
    'filter:none!important;-webkit-filter:none!important;mix-blend-mode:normal!important;opacity:1!important;visibility:visible!important',
    "fill=%22white%22", "fill=%22black%22",
]: assert tok in f, tok

# Existing earlier PDP owners remain present: OLED swatches, comparison/$59.97 family, Similar Brands gray borders.
for tok in [
    '#twister-plus-mobile-inline-twister-container .image-swatch-button.sml-image-swatch-button',
    '[class*=_rufus-comparison-card_style_',
    '#sims-discoveryAndInspiration_feature_div_0',
    '[class*=_multi-brand-video-mobile_',
    'border-color:#494d4d!important',
]: assert tok in S, tok

# SafeFrame lane now recognizes video/product renderers and tames product media while excluding semantic art.
sf=S[S.index('static NSString *ADPDPSafeFrameJS7432(void)'):S.index('// v7.439:', S.index('static NSString *ADPDPSafeFrameJS7432(void)'))]
assert ':has(video):has([class*=product])' in sf
assert ':has(video):has([data-testid*=product])' in sf
assert '${A} img:not([class*=logo]):not([class*=prime]):not([class*=star]):not([class*=rating]):not([class*=badge]):not([class*=icon]):not([class*=glyph]):not([class*=sprite]):not([class*=pixel])' in sf
assert 'mix-blend-mode:normal!important;opacity:1!important' in sf
for tok in ['.a-color-link', '.a-color-price', '[class*=prime]', '[class*=star]', '[class*=rating]', '[class*=deal]', '[class*=coupon]']:
    assert tok in sf, tok

# Search rail and Shop-by-brand owners remain exact and compile-safe.
assert ".s-widget-container[class*='widgetId=container-search-results_sponsored']>.s-container-results" in S
assert '[data-component-type=s-tiles-carousel-component-brand_logo]' in S
assert 'filter:brightness(.42)!important' in S

# No new recurring runtime mechanism in either new/strengthened path.
for chunk in (f, sf):
    for bad in ('new MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
        assert bad not in chunk, bad

print('PASS: v7.439 covers the probe-confirmed PDP standalone/video/lightAds/Safety-doc families while retaining all recent UI fixes')

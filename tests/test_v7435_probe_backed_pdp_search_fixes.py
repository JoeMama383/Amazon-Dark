from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
UI=(ROOT/'scripts/ui-probe.sh').read_text()
SK=(ROOT/'scripts/skeleton-probe.sh').read_text()
JS=(ROOT/'src/ADUniversalUIProbe7362.js.inc').read_text()
FJS=(ROOT/'src/ADUniversalUIProbe7362.frame.js.inc').read_text()

assert 'Version: 7.449~full-probe-nonblocking' in C
assert '#define AD_VERSION "v7.449-full-probe-nonblocking"' in S
assert 'VER=7.449' in UI
assert 'AD_PROBE_VERSION=7.449' in SK and 'AD_PROBE_NAME=AmazonDark-v7.449' in SK
assert "version:'7.449'" in JS and "version:'7.449'" in FJS

f=S[S.index('static NSString *ADPDPCompletionJS7405'):S.index('static NSString *ADPDPCompletionTWBJS7405')]
for tok in [
    "put('ad7435-pdp-child-ad-exact'",
    '#product-image-gallery :is(.a-cardui-title-text,.a-truncate,.a-truncate-cut',
    '#sims-multiProductBundle_feature_div_0,#multi-bundle-container-t3_feature_div) img.p13n-product-image',
    'filter:none!important;-webkit-filter:none!important;opacity:1!important;mix-blend-mode:normal!important;visibility:visible!important',
    '#ape_detail_mobile-app-detail-ilm_mshop_wrapper,#ape_detail_mobile-app-detail-ilm_mshop_placement',
    '#ape_detail_btf2_mshop_wrapper,#ape_detail_btf2_mshop_placement',
    '[id^=ad-feedback-sprite-]',
    'fill=%22white%22',
    'fill=%22black%22',
]:
    assert tok in f, tok

for tok in [
    '.s-result-item.AdHolder',
    'border-left-color:#000!important;border-right-color:#000!important',
    '[data-component-type=s-tiles-carousel-component-brand_logo]',
    'filter:brightness(.42)!important;-webkit-filter:brightness(.42)!important',
]:
    assert tok in S, tok

for bad in ('new MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in f, bad

print('PASS: v7.437 applies probe-backed PDP/Search fixes and current probe identities')

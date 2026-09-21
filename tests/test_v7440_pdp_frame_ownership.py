from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text()
C=(R/'layout/DEBIAN/control').read_text()
UI=(R/'scripts/ui-probe.sh').read_text()
SK=(R/'scripts/skeleton-probe.sh').read_text()
assert 'Version: 7.440~pdp-frame-ownership' in C
assert '#define AD_VERSION "v7.440-pdp-frame-ownership"' in S
assert 'VER=7.440' in UI
assert 'AD_PROBE_VERSION=7.440' in SK and 'AD_PROBE_NAME=AmazonDark-v7.440' in SK
# The correction changes delivery, not just selectors: enumerate WebKit child frames and evaluate in their page world.
for tok in ['NSSelectorFromString(@"_frames:")','evaluateJavaScript:inFrame:inContentWorld:completionHandler:','NSClassFromString(@"WKContentWorld")','NSSelectorFromString(@"pageWorld")','ADInjectFrameNode7440','ADForceChildFrameTheme7440']:
    assert tok in S,tok
# Event-driven reinjection catches initial, lazy, and navigated iframe loads with no recurring machinery.
bridge=S[S.index('static NSString *ADFrameOwnerTriggerJS7440'):S.index('static id ADPageWorld7440')]
for tok in ['adFrameOwner7440',"addEventListener('load'","tagName||''","'IFRAME'","DOMContentLoaded","pageshow","document-start"]: assert tok in bridge,tok
for bad in ['MutationObserver','setInterval(','requestAnimationFrame(',"addEventListener('scroll'"]:
    assert bad not in bridge,bad
# Child stylesheet is persistent/inert until an ad marker matches and owns the requested visual contract.
f=S[S.index('static NSString *ADForcedPDPFrameThemeJS7440'):S.index('static NSString *ADFrameOwnerTriggerJS7440')]
for tok in [
 'ad7440-forced-frame-theme','data-ad7440-frame-owner',':has([data-testid=product-card])',':has(.swiper-wrapper)',
 'background:#000!important','border-color:#494d4d!important','color:#e8e6e3!important',
 '[class*=prime]','[class*=star]','[class*=rating]','[class*=deal]','[class*=coupon]','-webkit-text-fill-color:currentColor!important',
 'img:not([class*=logo]):not([class*=prime]):not([class*=star])','mix-blend-mode:normal!important',
 '.swiper-button-next','.swiper-button-prev','stroke:#fff!important','ad-feedback-sprite'
]: assert tok in f,tok
for bad in ['MutationObserver','setInterval(','requestAnimationFrame(',"addEventListener('scroll'"]:
    assert bad not in f,bad
# Main-document residuals from the same screenshots are explicit too.
m=S[S.index('static NSString *ADPDPMainResidualJS7440'):S.index('// v7.412 FULL r1')]
for tok in ["[data-csa-c-painter='sb-collections-ilm-mobile']",'[class*=_c2ItY_cardWrapper_]','[class*=_c2ItY_asinImage_]','[class*=_rufus-comparison-card_style_insightText_]','rgb(11,123,60)']:
    assert tok in m,tok
# Existing successful/required fixes remain.
for tok in ['#product-image-gallery .a-truncate-cut','img.p13n-product-image',".s-widget-container[class*='widgetId=container-search-results_sponsored']>.s-container-results",'[data-component-type=s-tiles-carousel-component-brand_logo]']:
    assert tok in S,tok
print('PASS: v7.440 owns PDP ad child frames natively and closes current main-document residuals without recurring scans')

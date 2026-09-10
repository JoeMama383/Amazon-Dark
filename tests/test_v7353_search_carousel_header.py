from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
t=(ROOT/'src/Tweak.xm').read_text(); ui=(ROOT/'src/ADUniversalUIProbe7362.inc').read_text(); ctl=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.389~checkout-sheet-switcher-fix' in ctl
assert '#define AD_VERSION "v7.389-checkout-sheet-switcher-fix"' in t
# Search autocomplete large carousel owner + TWB.
for token in [
 '.cards_carousel_widget-sug-container-top{background:#000!important',
 '.cards_carousel_widget-sug-container-top img{filter:brightness(var(--ad7-cards-twb)) saturate(1)!important',
]: assert token in t,token
# Current featured-video label pill.
for token in [
 '.feature-asins-video-list-loader [class*=_controls_1m98b_] span[class*=_button_1wlc7_]{background:#000!important',
 'span[class*=_button_1wlc7_] .a-button-text{background:transparent!important',
]: assert token in t,token
# Certification shell remains transparent and outside broad TWB. v7.358 intentionally
# gives only the exact leaf raster its dedicated white-square neutralization filter.
assert '.s-pc-certification-faceout img.s-image{background:transparent!important' in t
assert '#search .s-pc-certification-faceout img.s-image{filter:invert(1) hue-rotate(180deg)!important' in t
# Top-reviewed tiles.
for token in [
 '#search .s-widget-container:has(.s-trft)',
 '#search .s-trft .s-trft-tile{background:#000!important',
 'border:1px solid #494d4d!important',
 '#search .s-trft-image-container img,#search img._c2Itd_image_3UiYm',
]: assert token in t,token
# Stock action controls are no longer force-inverted/force-silhouetted by exact old rules.
assert '#search .mlt-icon-container :is(img,svg,i,[class*=glyph],[class*=icon]){color:#0f1111' not in t
# Product-branch old MAB exact inversion removed; a later hands-off family backstop is present.
start=t.index("p==='/s'||p.indexOf('/s/')===0")
prod=t[start:t.index("else{s=put('ad7-me",start)]
assert '.puis-mab-chevron :is(i.a-icon-dropdown,.a-icon.a-icon-dropdown),.puis-mab-chevron-glyph ' not in prod
assert '.lists-framework-action-button.puis-heart-icon-container' in prod
assert '.mlt-icon-container,.puis-mab-chevron' in prod
# Broad product TWB is overridden for stock action/certification images.
assert '#search .mlt-icon-container img,#search .lists-framework-action-button.puis-heart-icon-container img' in t
# v7.362 removes route precedence entirely: both probe categories are universal across the current screen.
assert 'ADUIWebViews7362' in ui and 'ADTrackedWebViews()' in ui
assert 'ADProbeTabSelected7254' not in ui and 'ADProductScrollWebView7272' not in ui
# Accepted launch/cart protections survive.
for token in ['AmazonDarkSplashSeal7350','#sc-recs-atf-shimmer-placeholder{border-top-color:#000!important','ADBlackenLoadingGradient7348']:
 assert token in t,token
# v7.353 on-device corrections: media remains visible/tamed and TRFT header gradient is sealed.
assert '.cards_carousel_widget-sug-container-top img,.cards_carousel_widget-sug-container-top img[class*=cards_carousel_widget-sug-im]{background:transparent!important;visibility:visible!important;opacity:1!important' in t
assert '.cards_carousel_widget-sug-container-top{--ad7-cards-twb:%.3f;}' in t
assert '.cards_carousel_widget-sug-container-top img{filter:brightness(var(--ad7-cards-twb)) saturate(1)!important' in t
assert '#search .s-result-item:has([data-component-type=s-tiles-grid-component-top_reviewed_for])::before{background:#000!important' in t
assert '#search .s-widget-container:has(.s-trft) .s-tiles-header' in t
assert '[data-component-type=s-tiles-grid-component-top_reviewed_for] .s-tiles-header{background:#000!important' in t
assert '.s-tiles-header{background:#000!important' in t
print('PASS: v7.354 preserves v7.353 UI owners and TRFT header while narrowing Search carousel floor ownership')

from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
t=(ROOT/'src/Tweak.xm').read_text(); ctl=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.352~search-product-ui-repair' in ctl
assert '#define AD_VERSION "v7.352-search-product-ui-repair"' in t
# Search autocomplete large carousel owner + TWB.
for token in [
 '.cards_carousel_widget-sug-container-top{background:#000!important',
 '.cards_carousel_widget-sug-container-top [class*=cards_carousel_widget-sug-]',
 '.cards_carousel_widget-sug-container-top img,#attach-to-me img.s-image',
]: assert token in t,token
# Current featured-video label pill.
for token in [
 '.feature-asins-video-list-loader [class*=_controls_1m98b_] span[class*=_button_1wlc7_]{background:#000!important',
 'span[class*=_button_1wlc7_] .a-button-text{background:transparent!important',
]: assert token in t,token
# Sustainability/certification image is transparent and excluded from TWB.
assert '.s-pc-certification-faceout img.s-image{background:transparent!important' in t
assert '.s-pc-certification-faceout img.s-image{filter:none!important' in t or '#search .s-pc-certification-faceout img.s-image{background:transparent!important' in t
assert '#search .s-pc-certification-faceout img.s-image{filter:none!important' in t
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
# Search overlay product probe dispatch beats stale underlying menuTab selection.
da=t.index('static void ADCaptureThreeTabProbe7254(NSString *trigger){')
dispatch=t[da:t.index('static void ADInstallThreeTabProbes7254',da)]
assert dispatch.index('if(ADProductScrollWebView7272())') < dispatch.index('ADProbeTabSelected7254(@"home")')
assert dispatch.index('if(ADProductScrollWebView7272())') < dispatch.index('ADProbeTabSelected7254(@"menuTab")')
# Accepted launch/cart protections survive.
for token in ['AmazonDarkSplashSeal7350','#sc-recs-atf-shimmer-placeholder{border-top-color:#000!important','ADBlackenLoadingGradient7348']:
 assert token in t,token
print('PASS: v7.352 exact Search carousel, stock action-control, video pill, certification and TRFT owners present')

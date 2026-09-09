from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
t=(ROOT/'src/Tweak.xm').read_text(); ctl=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.375~checkout-prepaint-snapshot-hydration' in ctl
assert '#define AD_VERSION "v7.375-checkout-prepaint-snapshot-hydration"' in t
# Search: outer/card floor retained; broad descendant floor owner removed.
assert '.cards_carousel_widget-sug-container-top{background:#000!important' in t
assert '.cards_carousel_widget-sug-container-top .cards_carousel_widget-sug-column{background:#000!important' in t
assert '.cards_carousel_widget-sug-container-top [class*=cards_carousel_widget-sug-]:not(img):not(picture):not(source)' not in t
# Media-named descendants are released to transparent and exact historical IMG family stays visible/tamed.
assert '.cards_carousel_widget-sug-container-top [class*=cards_carousel_widget-sug-im]{background-color:transparent!important' in t
assert '.cards_carousel_widget-sug-container-top img,.cards_carousel_widget-sug-container-top img[class*=cards_carousel_widget-sug-im]{background:transparent!important' in t
assert '.cards_carousel_widget-sug-container-top img{filter:brightness(var(--ad7-cards-twb)) saturate(1)!important' in t
# Store Spotlight stable owner joins product TWB and tracker is excluded.
sel='#search [data-csa-c-painter=store-spotlight-v2-creative-mobile-cards] img:not([class*=_pixel_]):not([class*=tracking])'
assert sel in t
assert '{filter:brightness(%.3f)!important;-webkit-filter:brightness(%.3f)!important' in t
# Existing critical hands-off/preserved owners remain.
for token in [
 'AmazonDarkSplashSeal7350',
 '#sc-recs-atf-shimmer-placeholder{border-top-color:#000!important',
 '#search .s-pc-certification-faceout img.s-image{filter:invert(1) hue-rotate(180deg)!important',
 '#search .lists-framework-action-button.puis-heart-icon-container',
 '#search .s-result-item:has([data-component-type=s-tiles-grid-component-top_reviewed_for])::before{background:#000!important',
]: assert token in t,token
print('PASS: v7.354 restores Search carousel media ownership and tames Store Spotlight logo/product images')

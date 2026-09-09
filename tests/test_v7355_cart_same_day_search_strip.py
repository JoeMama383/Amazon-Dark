from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
t=(ROOT/'src/Tweak.xm').read_text()
ctl=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.386~sponsored-shell-ownership' in ctl
assert '#define AD_VERSION "v7.386-sponsored-shell-ownership"' in t
# Current Cart probe exact owners.
for token in [
    '#sc-page-container #ssd-ca-buy-box{background:#000!important',
    '#sc-page-container #ssd-ca-buy-box .a-meter{background:#000!important',
    '#sc-page-container #ssd-ca-buy-box .a-meter-bar{background:rgb(11,123,60)!important',
    '#sc-page-container #ssd-ca-buy-box #dex-basket-building-bottom-sheet-link.a-button{background:#303335!important',
    'border:1px solid #747a7c!important',
]: assert token in t, token
# v7.356 corrects the v7.355 image-adjacent selector to the exact title-strip owner.
assert '.cards_carousel_widget-sug-container-top .cards_carousel_widget-sug-text{background:#000!important' in t
assert '.cards_carousel_widget-sug-column :is(img,picture,[class*=cards_carousel_widget-sug-im]) + *{background:#000!important' not in t
assert '.cards_carousel_widget-sug-container-top [class*=cards_carousel_widget-sug-]:not(img):not(picture):not(source)' not in t
# v7.354 media visibility/TWB and Store Spotlight coverage remain.
for token in [
    '.cards_carousel_widget-sug-container-top img,.cards_carousel_widget-sug-container-top img[class*=cards_carousel_widget-sug-im]{background:transparent!important',
    '.cards_carousel_widget-sug-container-top img{filter:brightness(var(--ad7-cards-twb)) saturate(1)!important',
    '#search [data-csa-c-painter=store-spotlight-v2-creative-mobile-cards] img:not([class*=_pixel_]):not([class*=tracking])',
    '#search .s-pc-certification-faceout img.s-image{filter:invert(1) hue-rotate(180deg)!important',
    'AmazonDarkSplashSeal7350',
    '#sc-recs-atf-shimmer-placeholder{border-top-color:#000!important',
]: assert token in t, token
print('PASS: current build preserves v7.355 Cart Same-Day ownership and v7.356 exact Search title-strip correction')

from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
t=(ROOT/'src/Tweak.xm').read_text(); ctl=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.380~amznkiller-features-optimization-audit' in ctl
assert '#define AD_VERSION "v7.380-amznkiller-features-optimization-audit"' in t
# Search carousel: exact text strip; rejected image-adjacent black sibling rule gone.
assert '.cards_carousel_widget-sug-container-top .cards_carousel_widget-sug-text{background:#000!important' in t
assert '.cards_carousel_widget-sug-column :is(img,picture,[class*=cards_carousel_widget-sug-im]) + *{background:#000!important' not in t
assert '.cards_carousel_widget-sug-container-top img{filter:brightness(var(--ad7-cards-twb)) saturate(1)!important' in t
# v7.357+ replaces v7.356's missed delivery-class footer owner; title-strip/media contracts remain.
assert '.cards_carousel_widget-sug-container-top .cards_carousel_widget-sug-text{background:#000!important' in t
# Current /s theme collection card edge only.
assert '#search#search [class*=_c2Itd_themeCollectionAsinItem_]{border-color:#494d4d!important' in t
# Product variation/count toggle, selected blue ring.
assert '#search#search .puis-card-container .a-button.a-button-toggle{background:#000!important' in t
assert '.a-button.a-button-toggle.a-button-selected{background:#000!important' in t
assert 'box-shadow:inset 0 0 0 2px #2162a1!important' in t
# Current IES shell/card/button owners.
for token in [
    '#search#search .ies-wrapper,#search#search .ies-wrapper .ccs-close-button-wrapper',
    '.ies-wrapper .inline-expansion-slot-gradient-frame',
    '.ies-wrapper .a-cardui[class*=_mobile-ccs-ies-carousel-card_style_carouselCardContainer__]',
    '.ies-wrapper #ee-category-tabs .a-button.a-button-toggle{background:#000!important',
    '.ies-wrapper .add-to-cart-button.ccs-ies-atc-mini-size{background:#303335!important',
    '#search .ies-wrapper .ccs-ies-card-image-container img',
]: assert token in t, token
# Dynamic families are excluded from the scoped neutral ink override.
for token in ['not([class*=prime])','not([class*=star])','not([class*=deal])','not([class*=promotion])','not([class*=success])']:
    assert token in t, token
# Product stepper matches accepted Cart palette; +/- are light.
assert '#search#search .puis-card-container .a-stepper-inner-container{background:#303335!important' in t
assert 'border:1px solid #747a7c!important' in t
assert ':is(.a-icon-small-add,.a-icon-small-remove,.a-icon-small-subtract,.a-icon-small-trash){filter:brightness(0) invert(1)!important' in t
# v7.357 retired the disproven class-token guess; v7.358 further replaces the temporary text marker with the probe-proven Search Tiles renderer.
assert '[data-csa-c-painter*=shop-by-style]' not in t
assert 'data-ad7-shop-by-style' not in t
assert '[data-component-type=s-tiles-carousel-component-shoppable_image]' in t
# Existing critical contracts remain.
for token in ['AmazonDarkSplashSeal7350','#sc-recs-atf-shimmer-placeholder{border-top-color:#000!important','#ssd-ca-buy-box{background:#000!important']:
    assert token in t, token
print('PASS: v7.356 inline-ad/control fixes remain under the v7.358 exact Search Tiles ownership')

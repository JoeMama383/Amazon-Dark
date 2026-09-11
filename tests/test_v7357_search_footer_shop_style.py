from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
t=(ROOT/'src/Tweak.xm').read_text(); ctl=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.406~video-sponsored-footer-restore' in ctl
assert '#define AD_VERSION "v7.406-video-sponsored-footer-restore"' in t
# v7.357 fixed the white autocomplete footer by removing the failed delivery-class gate.
assert '#attach-to-me :is(div,section,article,main,footer,ul,ol,li,span):has(:is([class*=delivery],[id*=delivery])){background:#000!important' not in t
assert 'body>:is(div,section,main,footer),#a-page>:is(div,section,main,footer),#attach-to-me>:is(div,section,main,footer)' in t
assert '#attach-to-me>:is(div,section,main,footer)>:is(div,section,article,main,footer){background-color:#000!important' in t
assert '#attach-to-me :is(.a-button,button,[role=button]){background:#000!important' not in t
assert '#attach-to-me :is(div,section,article,main,footer,ul,ol,li,span):has(:is([class*=delivery],[id*=delivery])) :is(.a-button,.a-button-inner,button,[role=button]){background:#000!important' in t
# v7.358 must not undo the repeatedly-regressed autocomplete carousel media ownership.
assert '.cards_carousel_widget-sug-container-top [class*=cards_carousel_widget-sug-im]{background-color:transparent!important' in t
assert '.cards_carousel_widget-sug-container-top img{filter:brightness(var(--ad7-cards-twb)) saturate(1)!important' in t
assert '[class*=cards_carousel_widget-sug-]:not(img):not(picture):not(source){background-color:#000!important' not in t
# v7.356 guessed class tokens remain retired.
assert '[data-csa-c-painter*=shop-by-style]' not in t
assert '[class*=shopByStyle]' not in t
# Temporary v7.357 text-marker machinery is intentionally gone in favor of probe-proven exact Search Tiles ownership.
assert 'function ad7357ShopByStyle()' not in t
assert 'data-ad7-shop-by-style' not in t
assert '[data-component-type=s-tiles-carousel-component-shoppable_image]' in t
# Older critical contracts remain.
for token in ['.ies-wrapper .add-to-cart-button.ccs-ies-atc-mini-size','#search .ies-wrapper .ccs-ies-card-image-container img','.a-stepper-inner-container{background:#303335!important','AmazonDarkSplashSeal7350','#ssd-ca-buy-box{background:#000!important']:
    assert token in t, token
print('PASS: v7.357 Search footer/media protections remain; temporary Shop-by-style marker safely retired in v7.358')

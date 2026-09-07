from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
t=(ROOT/'src/Tweak.xm').read_text(); ctl=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.357~search-footer-shop-style-fix' in ctl
assert '#define AD_VERSION "v7.357-search-footer-shop-style-fix"' in t
# The v7.356 footer guess required a delivery class/id and missed the live white plane.
assert '#attach-to-me :is(div,section,article,main,footer,ul,ol,li,span):has(:is([class*=delivery],[id*=delivery])){background:#000!important' not in t
# v7.357 owns only first/second structural layers by background color; it does not clear media background images.
assert 'body>:is(div,section,main,footer),#a-page>:is(div,section,main,footer),#attach-to-me>:is(div,section,main,footer)' in t
assert '#attach-to-me>:is(div,section,main,footer)>:is(div,section,article,main,footer){background-color:#000!important' in t
assert '#attach-to-me :is(.a-button,button,[role=button]){background:#000!important' in t
assert 'border:1px solid #747a7c!important' in t
# Protect the repeatedly-regressed autocomplete media family.
assert '.cards_carousel_widget-sug-container-top [class*=cards_carousel_widget-sug-im]{background-color:transparent!important' in t
assert '.cards_carousel_widget-sug-container-top img{filter:brightness(var(--ad7-cards-twb)) saturate(1)!important' in t
assert '[class*=cards_carousel_widget-sug-]:not(img):not(picture):not(source){background-color:#000!important' not in t
# Retire the class-token guess that the on-device v7.356 screenshot disproved.
assert '[data-csa-c-painter*=shop-by-style]' not in t
assert '[class*=shopByStyle]' not in t
# Bounded exact-heading marker and marker-owned surfaces/TWB.
for token in [
    'function ad7357ShopByStyle()',
    'document.createTreeWalker(r,NodeFilter.SHOW_TEXT)',
    'seen++<7000',
    "v==='shop by style'",
    "best.setAttribute('data-ad7-shop-by-style','1')",
    '#search#search [data-ad7-shop-by-style=',
    '{background:#000!important;background-color:#000!important;background-image:none!important;border-color:#494d4d!important',
    '#search [data-ad7-shop-by-style=',
    'img:not([class*=icon]):not([class*=glyph]):not([class*=badge]):not([class*=pixel]):not([class*=tracking]){filter:brightness(%.3f)!important',
]: assert token in t, token
# No recurring discovery machinery is added for this correction.
marker=t[t.index('function ad7357ShopByStyle()'):t.index("if(document.rea", t.index('function ad7357ShopByStyle()'))]
assert 'MutationObserver' not in marker
assert 'setInterval' not in marker
assert 'requestAnimationFrame' not in marker
assert "addEventListener('scroll'" not in marker
# Preserve current exact product fixes and older visual contracts.
for token in ['.ies-wrapper .add-to-cart-button.ccs-ies-atc-mini-size','#search .ies-wrapper .ccs-ies-card-image-container img','.a-stepper-inner-container{background:#303335!important','AmazonDarkSplashSeal7350','#ssd-ca-buy-box{background:#000!important']:
    assert token in t, token
print('PASS: v7.357 removes both disproven selector guesses; structural Search seal and bounded Shop-by-style marker/TWB are wired')

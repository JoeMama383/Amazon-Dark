from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
t=(ROOT/'src/Tweak.xm').read_text(); ctl=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.360~search-tiles-cart-coupon-fix' in ctl
assert '#define AD_VERSION "v7.360-search-tiles-cart-coupon-fix"' in t
# Search regression: v7.357 structural seal must not recolor stock row/close-button borders or outlines.
needle='body>:is(div,section,main,footer),#a-page>:is(div,section,main,footer),#attach-to-me>:is(div,section,main,footer)'
i=t.index(needle); rule=t[i:t.index('}',i)+1]
assert 'background-color:#000!important' in rule
assert 'border-color:' not in rule
assert 'outline-color:' not in rule
assert 'box-shadow:' not in rule
assert '#attach-to-me :is(.a-button,button,[role=button]){background:#000!important' not in t
assert '#attach-to-me :is(div,section,article,main,footer,ul,ol,li,span):has(:is([class*=delivery],[id*=delivery])) :is(.a-button,.a-button-inner,button,[role=button]){background:#000!important' in t
# Exact current Shop-by-style family from v7.357 /s probe: SEARCH_TILES + shoppable-image carousel.
family='[data-component-type=s-tiles-carousel-component-shoppable_image]'
assert family in t
assert '.s-widget-container:has('+family+')' in t
assert '.s-tiles-carousel::before' in t
assert '.s-result-item:has('+family+')::before{background:#000!important' in t
assert 'img.scx-si-image{filter:brightness(%.3f)!important' in t
assert 'function ad7357ShopByStyle()' not in t
assert 'document.createTreeWalker(r,NodeFilter.SHOW_TEXT)' not in t
# Certification/Forestry leaf: DOM shell stays transparent, exact 16px raster neutralizes its baked white square.
assert '#search .s-pc-certification-faceout,#search .s-pc-attribute-pill-text.s-pc-certification-faceout{background:transparent!important' in t
assert '#search .s-pc-certification-faceout img.s-image{background:transparent!important;background-color:transparent!important;filter:invert(1) hue-rotate(180deg)!important' in t
assert '#search .s-pc-certification-faceout img.s-image{filter:invert(1) hue-rotate(180deg)!important' in t
# No new recurring production mechanism.
assert 'setInterval(' not in t
assert 'requestAnimationFrame(' not in t
print('PASS: v7.358 removes Search row boxes, seals Search Tiles pseudo floors, and neutralizes certification raster white square')

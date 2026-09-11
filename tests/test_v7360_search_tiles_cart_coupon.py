from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
t=(ROOT/'src/Tweak.xm').read_text()
ctl=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.405~pdp-completion' in ctl
assert '#define AD_VERSION "v7.405-pdp-completion"' in t

# Current Search Tiles probe proves the IMG itself already had brightness TWB while
# its exact image container still retained Amazon's gradient painter. Remove only
# that family background-image and keep media leaf ownership inside the exact tile container.
assert '#search [data-component-type=s-tiles-carousel-component] .scx-stt-image-container,#search .scx-stt-image-container{background:#000!important;box-shadow:none!important;}' in t
assert '#search [data-component-type=s-tiles-carousel-component] .scx-stt-image-container img,#search img.scx-stt-image' in t
assert 's-tiles-carousel-component-shoppable_image' in t  # preserve v7.358 Shop-by-style lane

# Cart coupon must use the same true-green/white contract as Search coupons, while
# neutral Undo remains neutral and glyph/image leaves are not filtered/recolored.
assert '#search#search .s-coupon-tile' in t and 'background:#008000!important' in t
cart='#sc-page-container :is(.sc-clipcoupon-container,[data-csa-c-painter=cart-coupon]) .sc-coupon-wrapper>.a-button'
assert cart in t
start=t.index(cart)
block=t[start:start+1700]
assert 'background:#008000!important' in block
assert 'border:1px solid #008000!important' in block
assert 'color:#fff!important;-webkit-text-fill-color:#fff!important' in block
assert '.a-button-text :is(i,svg,img,[class*=icon],[class*=glyph],[class*=checkbox]){filter:none!important;-webkit-filter:none!important;}' in block
assert '#sc-page-container .sc-list-item-removed-msg .sc-undo-delete-btn{background:#303335!important' in t

# No new production recurring mechanism.
assert 'setInterval(' not in t
assert 'requestAnimationFrame(' not in t
print('PASS: v7.360 seals Search Tiles image planes/tames exact tile media family and restores Cart coupon green/white parity')

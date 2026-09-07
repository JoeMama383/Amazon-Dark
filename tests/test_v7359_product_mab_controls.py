from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
t=(ROOT/'src/Tweak.xm').read_text(); ctl=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.360~search-tiles-cart-coupon-fix' in ctl
assert '#define AD_VERSION "v7.360-search-tiles-cart-coupon-fix"' in t

# Probe-proven product-card Heart shell: neutral fill/edge; only its glyph leaf is whitened.
assert '#search .lists-framework-heart-background{background:#303335!important;background-color:#303335!important;background-image:none!important;border:1px solid #747a7c!important' in t
assert '#search .lists-framework-heart-background .lists-framework-unfilled-heart-icon{color:#e8e6e3!important;fill:#e8e6e3!important;stroke:#e8e6e3!important;filter:brightness(0) invert(1) brightness(.91)!important' in t

# Probe-proven chevron host: neutral at rest; Amazon-authored open blue ring remains exact.
assert '#search .puis-mab-chevron{background:#303335!important;background-color:#303335!important;background-image:none!important;border:1px solid #747a7c!important' in t
assert '#search .puis-mab-chevron :is(i.a-icon-dropdown,.a-icon.a-icon-dropdown){filter:brightness(0) invert(1) brightness(.91)!important' in t
assert '#search .puis-mab-container.puis-mab-open>.puis-mab-chevron{background:#303335!important;background-color:#303335!important;border-color:rgb(28,137,227)!important' in t

# Historical/current probe-proven main More-like-this/two-cards family only; hidden compare experiment is not restyled.
assert '#search .puis-mab-spotlight-slot-mlt .mlt-icon-container{background:#303335!important;background-color:#303335!important;background-image:none!important;border:1px solid #747a7c!important' in t
assert '#search .puis-mab-spotlight-slot-mlt .mlt-icon-container img.s-image{background:transparent!important;background-color:transparent!important;filter:brightness(0) invert(1) brightness(.91)!important' in t
assert '#search .puis-mab-spotlight-slot-compare' not in t
assert 'puis-copilot-product-comparison-checkbox' not in t

# Exact MAB overlay: OLED shell/rows, standard gray separators, last row ringless.
assert '#search .puis-mab-overlay{background:#000!important;background-color:#000!important;background-image:none!important;border:1px solid #494d4d!important' in t
assert '#search .puis-mab-overlay .puis-mab-overlay-row{background:#000!important;background-color:#000!important;background-image:none!important;border:0!important;border-bottom:1px solid #494d4d!important' in t
assert '#search .puis-mab-overlay .puis-mab-overlay-row-share{border-bottom:0!important' in t
assert '#search .puis-mab-overlay :is(.puis-mab-overlay-row-label,.puis-mab-overlay-row-label span,.puis-mab-overlay-row-widget){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important' in t

# Leaf-only menu glyph ownership: Save background image inverted; Select sprite inverted/transparent;
# Share keeps Amazon mask and changes only mask ink; MLT is ringless inside menu and its IMG is white.
assert '#search .puis-mab-overlay .puis-mab-overlay-heart{background-color:transparent!important' in t
assert 'filter:brightness(0) invert(1) brightness(.91)!important' in t
assert '#search .puis-mab-overlay .puis-mab-overlay-row-select i.a-icon-checkbox{background-color:transparent!important;color:#e8e6e3!important;fill:#e8e6e3!important;stroke:#e8e6e3!important;border:0!important;box-shadow:none!important;filter:brightness(0) invert(1)!important' in t
assert '#search .puis-mab-overlay .puis-mab-overlay-icon-share{background-color:#e8e6e3!important' in t
assert '#search .puis-mab-overlay .puis-mab-overlay-row-mlt .mlt-icon-container{background:transparent!important;background-color:transparent!important;border-color:transparent!important' in t
assert '#search .puis-mab-overlay .puis-mab-overlay-row-mlt .mlt-icon-container img.s-image{filter:brightness(0) invert(1) brightness(.91)!important' in t

# The later product TWB sheet must not reclaim MLT images with its broad filter:none exception.
assert '#search .puis-mab-spotlight-slot-mlt .mlt-icon-container img.s-image,#search .puis-mab-overlay .puis-mab-overlay-row-mlt .mlt-icon-container img.s-image{filter:brightness(0) invert(1) brightness(.91)!important' in t

# v7.358 accepted contracts remain present.
for token in [
    '[data-component-type=s-tiles-carousel-component-shoppable_image]',
    '#search .s-pc-certification-faceout img.s-image{background:transparent!important',
    '.cards_carousel_widget-sug-container-top img{filter:brightness(var(--ad7-cards-twb)) saturate(1)!important',
    'AmazonDarkSplashSeal7350',
    '#ssd-ca-buy-box{background:#000!important',
]: assert token in t, token

# CSS-only delta: no new production recurring mechanism.
assert 'setInterval(' not in t
assert 'requestAnimationFrame(' not in t
print('PASS: v7.359 themes exact MAB menu/Heart/chevron/two-cards owners and preserves the open blue ring')

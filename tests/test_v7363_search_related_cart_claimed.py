from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
t=(ROOT/"src/Tweak.xm").read_text()
ctl=(ROOT/"layout/DEBIAN/control").read_text()
assert "Version: 7.388~native-work-optimization" in ctl
assert "#define AD_VERSION \"v7.388-native-work-optimization\"" in t
# Search autocomplete: broad black-plane ownership must skip image/icon artwork owners.
assert "[class*=autocomplete]:not([class*=icon]):not([class*=glyph]):not([class*=image])" in t
assert "[class*=suggestion]:not([class*=icon]):not([class*=glyph]):not([class*=image])" in t
assert ".s-suggestion-container img.s-suggestion-image-left{background:transparent!important" in t
assert ".s-suggestion-rufus-autocomplete-bh-mshop-icon-container,.s-suggestion-rufus-autocomplete-bh-mshop-icon{background-color:transparent!important" in t
# The exact product-thumbnail leaf joins the existing autocomplete TWB lane.
assert ".s-suggestion-container img.s-suggestion-image-left{filter:none!important;-webkit-filter:none!important;opacity:%.3f!important;visibility:visible!important;mix-blend-mode:normal!important;}" in t
# Product Search Related Searches exact card family.
assert "#search .textref-box-group .textref-border.textref-box-onlychild{background:#000!important" in t
assert "border:1px solid #494d4d!important" in t
assert "#search .textref-box-group i.a-icon-search.textref-icon-opacity" in t
assert "filter:brightness(0) invert(1)!important" in t
# Cart Apex claimed state is anchored to the state-stable container.
assert "#sc-page-container .apex-coupon-tile-container.apex-coupon-tile-mobile .apex-coupon-tile{background:#008000!important" in t
assert ".apex-coupon-tile.claimed svg.apex-coupon-success path.apex-coupon-icon-background{fill:#000!important" in t
assert ".apex-coupon-tile.claimed svg.apex-coupon-success path:not(.apex-coupon-icon-background){fill:#fff!important" in t
# Cart promotion badges: calmer green with OLED-black copy at stronger specificity than generic Cart whitening.
assert "#sc-page-container#sc-page-container .sc-unified-promotion-message-badge{background:#5a9e43!important" in t
assert "#sc-page-container#sc-page-container .sc-unified-promotion-message-badge :is(" in t
assert "color:#000!important;-webkit-text-fill-color:#000!important" in t
# No new recurring production machinery.
assert "MutationObserver(" not in t
assert "setInterval(" not in t
assert "requestAnimationFrame(" not in t
print("PASS: v7.363 Search-pane media/Rufus, Related Searches, claimed Cart coupon and promotion-badge fixes present")

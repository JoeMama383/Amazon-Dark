# AmazonDark v7.437 audit — PDP standalone ad treatment

## Exact parent

- Parent: `7.436~probe-backed-pdp-search-fixes`
- Parent archive: `AmazonDark-v7.436-search-sponsored-rails-fix-source.zip`
- Parent SHA256: `d91f285956f0619290d603ea7d039c4e9f3fefacb458093041c69220147003b8`

## Evidence

Three v7.435 FULL captures define this build:

1. `20260920-230936-838-r1`: the Product-image-gallery video ad is owned by `#universal-hero-quick-promo_feature_div` → `#ape_detail_mobile-hero-quick-promo_mshop_wrapper` → `#ape_detail_mobile-hero-quick-promo_mshop_placement` → its SafeFrame iframe.
2. `20260920-231232-801-r2`: the top standalone carousel is a main-document `text/x-APE-lightAds` renderer with stable painter `sb-collections-ilm-mobile` and `_c2ItY_*` product-card classes. Its card/container floors are computed white; its neutral price copy is `rgb(15,17,17)`; the product image is complete but uses `mix-blend-mode: darken`.
3. `20260920-231544-611-r1`: the bright Safety-documents card is the current `#mobile-ads-middle-app-dramabot_feature_div` → `#ape_detail_btf_mshop_wrapper` → `#ape_detail_btf_mshop_placement` → `#ape_detail_btf_mshop_iframe`. The main placement already owns the gray edge, proving the remaining white plane is inside the child renderer.

## Runtime delta

- Extends the existing PDP completion stylesheet with exact main-frame owners for the current APE IDs and the `sb-collections-ilm-mobile` lightAds family.
- Extends the existing configurable PDP TWB list to the `_c2ItY_asinImage_` raster family.
- Strengthens the existing all-frame `ADPDPSafeFrameJS7432` stylesheet. Dynamic CSS `:has()` activation is used so late ad hydration is handled without an observer or polling.
- No new user script, bridge, hook, timer, observer, RAF loop, scroll listener, or recurring hierarchy traversal is introduced.

## Color/media contract

- Neutral structural floors: OLED black.
- Existing structured card edges: standard `#494d4d`; outer APE wrappers/iframes stay frameless to avoid duplicate borders.
- Neutral copy/current price: light.
- Authored link/Prime/star/rating/badge/deal/coupon/savings/promotion colors: preserved with `currentColor` ownership.
- Product raster media: existing user-configurable white-tame brightness factor; normal blend mode; brand logos/icons/Prime/rating art excluded from the SafeFrame raster tamer.

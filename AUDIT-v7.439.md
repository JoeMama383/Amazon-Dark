# AmazonDark v7.439 audit — probe-backed PDP UI completion

## Exact parent

- Parent: `7.438~compile-fix`
- Parent archive: `AmazonDark-v7.438-compile-fix-source.zip`
- Parent SHA256: `93c1fb62cc3ed812177e97c25d11ecf1d8df1e0de1ed01385536cc19c79325be`

## Why this release exists

The v7.435 FULL captures exposed three still-live PDP ad presentations: the hero/video card, the top `sb-collections-ilm-mobile` carousel, and the current Safety-documents `ape_detail_btf_mshop` SafeFrame. Earlier releases owned portions of these families but did not consistently give the actual current outer placement, inner lightAds shell, and child-frame renderer the same OLED contract.

## Exact ownership added/strengthened

- `#ape_detail_mobile-hero-quick-promo_mshop_placement`
- `#ape_detail_btf_mshop_placement`
- retained alternate `#ape_detail_btf2_mshop_placement`
- `#ape_detail_mobile-app-detail-ilm_mshop_placement`
- current wrappers and all four corresponding iframes are frameless to prevent duplicate borders
- `[data-csa-c-painter='sb-collections-ilm-mobile']` and `_c2ItY_cardWrapper_ / container_ / containerInner_` are OLED
- SafeFrame activation recognizes the existing Amazon ad roots plus video/product renderer signatures
- child-frame raster taming applies to neutral product media while excluding logo/Prime/star/rating/badge/icon/glyph/sprite/pixel art

## Preservation contract

Neutral surfaces become OLED black, neutral copy becomes light, and the placement owns one standard `#494d4d` edge. Authored links, Prime, ratings/stars, price/status/deal/coupon/savings/promotion families keep their semantic rendering. Media blending is normalized to avoid white/darken compositing artifacts.

## Retained probe-backed fixes

v7.439 retains the exact Product-image-gallery `.a-truncate-cut` light-text fix, multi-bundle image release, Sponsored white-circle/black-`i` glyph, Similar-brands gray borders, Yellow/Blue OLED swatches, comparison-card treatment, Search sponsored parent rail ownership, and Shop-by-brand logo taming.

## Runtime/performance

No MutationObserver, polling interval, RAF loop, web scroll listener, or recurring hierarchy scan is added. The new main-frame completion is one declarative style injection in the existing core Web script. SafeFrame theming remains an existing all-frame document-start style path.

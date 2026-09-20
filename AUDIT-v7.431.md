# AmazonDark v7.431 audit

## Parent

`7.430~native-review-menu` from `AmazonDark-v7.430-native-review-menu-source.zip` (SHA-256 `ed7fd2521f588735c10391ed7a3860b9bd00b5dd01e77d2ebc4f4172478c96d9`).

## Probe-backed changes

- r2: `Product image gallery` is an `.image-gallery-expander-heading` / `.a-expander-prompt`, so the prior `h2,h3` selector could not reach it. The exact expander family is now light.
- r2: the visible sponsored hero is `#universal-hero-quick-promo_feature_div` -> `#ape_detail_mobile-hero-quick-promo_mshop_*`, a separate APE family from the previously handled mobile ILM placement. That shell is now explicitly OLED/gray-edge owned. Neutral structural wrappers in PDP child ad documents inherit the black body instead of retaining white card floors; media remains excluded.
- r4: the visible color cards are `.image-swatch-button.sml-image-swatch-button` under `#twister-plus-mobile-inline-twister-container`, not the older `#hmod-swatch-list` family. Their floor is now OLED black; no selected border color is forced.
- r5: the white `$59.97` unit is the lower `#ape_detail_btf2_mshop_*` APE placement. That shell receives the same OLED/gray-edge ownership, and neutral sponsored prices are explicitly light while `.a-color-price` remains authored.
- r5: Similar Brands uses `_multi-brand-video-mobile_...` containers under `#sims-discoveryAndInspiration_feature_div_0`. Only the card/container edge families are normalized to `#494d4d` gray; video/image/media color remains unchanged.

## Runtime/performance contract

No new MutationObserver, timer, interval, RAF loop, Web scroll listener, recurring hierarchy scan, or broad media inversion was added. Existing v7.430 native review-menu work and prior lifecycle fixes are retained unchanged except for release/probe identity.

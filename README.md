# AmazonDark v7.437 — PDP standalone ad treatment

Exact parent: v7.436 `search-sponsored-rails-fix`.

v7.437 applies the established standalone-ad dark treatment to the three PDP ad renderers exposed by the latest v7.435 FULL probes while retaining the v7.436 Search sponsored-rail correction.

## Probe-backed fixes

- Product-image-gallery video sponsored card (`universal-hero-quick-promo` / `ape_detail_mobile-hero-quick-promo`): OLED child-frame structural floors, light neutral copy, existing border recolored to standard gray, product raster taming, dynamic Prime/star/deal/link colors preserved.
- Top standalone carousel (`mobile-app-detail-ilm` / `text/x-APE-lightAds` / `sb-collections-ilm-mobile`): OLED card/container floors, light neutral price/copy, one standard gray outer edge, authored semantic colors preserved, `_c2ItY_asinImage_` product rasters moved into the existing configurable white-tamer and forced to normal blend mode.
- Safety-documents standalone card (`mobile-ads-middle-app-dramabot` / `ape_detail_btf_mshop`): current middle/btf ownership added; outer wrapper/iframe stay frameless while the embedded renderer gets OLED planes, light neutral text, gray existing border color, and tamed product imagery.
- SafeFrame activation is still declarative and inert until an Amazon ad-renderer signature exists. Additional signatures cover `#dynamic-bb`, `gridContainer`, `prod-img`, product-description, brand-product-description and product-image families.
- Sponsored info glyph remains the established white circle with a black `i`.

No MutationObserver, polling interval, RAF loop, Web scroll listener, or recurring hierarchy scan is added. FULL, VIEWPORT and TRANSITION probe identities are regenerated to v7.437.

See `AUDIT-v7.437.md`, `VALIDATION-v7.437.md`, and `COMMANDS.md`.

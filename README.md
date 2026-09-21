# AmazonDark v7.439 — probe-backed PDP UI completion

v7.439 is a clean release cut from the exact corrected v7.438 source. It retains the v7.436 sponsored-search rail fix, the v7.437 standalone-ad work, and the v7.438 compile/strict-validation corrections, then closes the remaining probe-backed PDP ad families without adding recurring runtime machinery.

## Current UI coverage

- PDP hero/video standalone ad: OLED neutral surfaces, one standard gray placement edge, frameless wrapper/iframe, light neutral copy, tamed product raster, semantic colors preserved.
- PDP top `sb-collections-ilm-mobile` carousel: exact `_c2ItY_*` white shells are OLED, neutral black copy is light, Prime/stars/links/deals remain authored, product images use the existing tame policy, and the iframe/wrapper do not create a duplicate border.
- PDP Safety-documents standalone ad: current `mobile-ads-middle-app-dramabot -> ape_detail_btf_mshop_*` family is explicitly owned; outer placement gets the standard gray edge while the SafeFrame interior is dark-themed.
- Product image gallery heading: exact `.a-truncate-cut`/title/expander leaves are light.
- Customers-also-bought / Frequently-bought product art: exact multi-bundle `p13n-product-image` media is released from the global dimming filter while its neutral image/selection floors stay OLED.
- Sponsored feedback: neutral Sponsored copy is light and the info glyph is a visible white circle with a black `i`.
- PDP Yellow/Blue image swatches remain OLED black.
- PDP `$59.97`/comparison-card and Similar-brands video families retain their existing OLED/gray-border treatment.
- Search sponsored-results parent rails remain OLED black using the probe-confirmed `widgetId=container-search-results_sponsored` ancestor owner.
- Search Shop-by-brand keeps its exact `s-tiles-carousel-component-brand_logo` taming treatment.

FULL, VIEWPORT, and TRANSITION probe identities are regenerated to v7.439.

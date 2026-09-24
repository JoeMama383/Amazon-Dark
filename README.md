# AmazonDark v7.473 — persistent survivor sheet for uncovered standalone ads

Direct parent: **v7.472~pdp-standalone-unification**.

The v7.472 VIEWPORT capture finally separates delivery from selector coverage. The large 402x283 child frame reports `standalone7104=1`, proving that the mature standalone engine really is running there, while `gridContainer` still computes white, `productTitle`/price still compute dark, and the 53x15 Prime artwork is still filtered at `brightness(0.42)`. The problem is therefore not that AmazonDark failed to enter the frame. The mature standalone stylesheet simply does not contain selectors for these newer PDP renderer families.

A second diagnostic blind spot contributed to the repeated misdiagnosis: the cross-frame VIEWPORT probe only inventoried DOM `<style>` and `<link rel=stylesheet>` nodes. The working standalone implementation uses a constructable `CSSStyleSheet` in `document.adoptedStyleSheets`, so the probe could report no AmazonDark style node even when the working engine was active.

v7.473 keeps `ADStandalonePaintJS7104()` byte-for-byte frozen and extends the existing all-frame core payload `ADPDPGridCarouselFix7454()` with a second constructable survivor sheet. This is the same persistence mechanism as the working standalone engine: create one `CSSStyleSheet`, `replaceSync()` once, append it to `document.adoptedStyleSheets`, and re-own it on `pageshow`. It is installed at document start before renderer hydration, so Amazon replacing its DOM cannot delete the theme sheet.

Exact probe-backed coverage:

- **Top compact/offsite card:** the actual 414x51 `rgb(248,248,248)` direct child of `renderer-factory-ad-container` is made OLED, its gray rounded edge is retained, `mix-blend-mode:multiply` is released, and only the measured brand/product neutral leaves are made white. Sponsored/info semantics remain scoped separately.
- **Odd 402x125 grid/Swiper card:** `gridContainer`, zinc/white slide floors and neutral price leaves are darkened. The square outer/slide borders are removed only when a `.swiper-wrapper` proves the carousel family, while the rounded `gridRegionCarousel` keeps one gray edge. Arrows and product media remain untouched.
- **AUI `sp_hqp_phoneapp_shared` medium card:** the A-box and authored inner gradient become OLED and the measured neutral title/rating-count/price copy becomes white. Orange star and Prime sprite families are not recolored or filtered by this sheet.
- **402x283 structured grid card:** the non-Swiper grid gets an OLED floor with one gray outer edge, white neutral title/price leaves, existing TWB on the product image remains, and only the exact 53x15 Prime image under `dealprice-stack` is released from TWB so its authored orange check and blue Prime text return to full color.

The existing full-raster/TWB architecture remains unchanged; v7.473 does not recolor raster pixels. The v7.470 Book-details PUTB `::before` gradient removal remains active.

The VIEWPORT probe is expanded for verification. Each child-frame payload now reports `frameMeta.survivor7473`, inventories `document.adoptedStyleSheets`, and records rule count/hash plus whether an adopted sheet contains the v7.473 standalone-family signatures. This closes the old probe blind spot without adding production work.

No MutationObserver, interval, requestAnimationFrame loop, Web scroll listener, polling loop, or recurring DOM scan is added.

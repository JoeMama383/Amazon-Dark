# AmazonDark v7.440 audit — PDP frame ownership correction

## Exact parent

- Parent: `7.439~pdp-ui-completion`
- Parent archive: `AmazonDark-v7.439-pdp-ui-completion-release-source.zip`
- Parent release SHA256: `5e66260d9f1a971588bed0ec90520494fc1c33257871e231c2af2c23c6ef9e98`

## Why v7.439 did not land the stubborn ad fixes

The v7.435 FULL captures contained the live APE/SafeFrame iframe owners, including the Safety-documents `ape_detail_btf_mshop_iframe`, while the exported captures contained no `CROSS_FRAME_DOM` section for those renderer documents. That means the prior all-frame WKUserScript path was not a sufficient proof that AmazonDark CSS reached the document that painted the white card.

v7.440 changes the delivery mechanism instead of adding another parent-document selector layer.

## Runtime correction

`ADForceChildFrameTheme7440` asks WebKit for its actual frame tree using the iOS 14+ `_frames:` SPI. `_WKFrameTreeNode` exposes `info` and `childFrames` on iOS 17; each non-main `WKFrameInfo` is targeted with `evaluateJavaScript:inFrame:inContentWorld:completionHandler:` in `WKContentWorld.pageWorld`.

The child document receives `ad7440-forced-frame-theme` and the `data-ad7440-frame-owner` marker. The stylesheet remains inert unless ad/product markers are present, then applies the standard AmazonDark ad contract:

- OLED black neutral floors
- standard `#494d4d` edges
- light neutral copy
- dark neutral controls with white arrows/glyphs
- product-raster taming using the configured white-tame strength
- `mix-blend-mode: normal` for media
- visible Sponsored feedback treatment
- authored Prime/star/rating/deal/coupon/savings/promotion/badge/success/link colors excluded from neutral recoloring

A single capture-phase iframe `load` listener plus finite `DOMContentLoaded`, `load`, and `pageshow` lifecycle events requests reinjection after lazy frame navigation. There is no MutationObserver, timer/polling loop, RAF loop, web scroll listener, or recurring hierarchy scan.

## Main-document residuals addressed

- Strengthens the probe-confirmed `sb-collections-ilm-mobile` / `_c2ItY_*` standalone carousel floors, text, product-media treatment, and neutral arrows.
- Raises the probe-confirmed `_rufus-comparison-card_style_insightText_*` copy from dark gray to readable secondary light text while preserving the green insight dots.

## Retained UI corrections

v7.440 preserves the successful or still-required v7.435–v7.439 rules for Product image gallery text, multi-bundle product-image release, Sponsored glyph treatment, Similar Brands gray borders, Yellow/Blue OLED swatches, comparison-card treatment, Search sponsored parent rails/containers/text, and Shop-by-brand logo taming.

## Validation policy

This release is source/probe-backed and runtime-delivery-corrected. It is not called device-proven until the v7.440 package builds in GitHub CI and the target screens are visually checked on the phone.

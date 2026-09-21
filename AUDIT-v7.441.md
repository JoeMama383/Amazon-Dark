# AmazonDark v7.441 audit

Parent: v7.440-pdp-frame-ownership.

Primary correction: v7.440 enumerated only WebKit `_frames:`. On iOS 17, cross-origin/site-isolated renderer processes can live in separate frame trees exposed by `_frameTrees:`. v7.441 enumerates every `_frameTrees:` root, recursively injects the existing PDP ad treatment into each non-main `WKFrameInfo` in the page world, and retains `_frames:` as a compatibility/fallback path. The operation remains event-driven and idempotent.

Retained UI contract: OLED neutral ad floors, standard gray borders, light neutral text, neutral raster taming, visible neutral arrows/info glyphs, with Prime/stars/ratings/links/deal/coupon/savings/promotional semantic colors excluded from neutral recoloring. Existing v7.439/v7.440 main-document PDP and Search corrections remain intact.

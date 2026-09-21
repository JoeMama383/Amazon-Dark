# AmazonDark v7.440 — PDP frame ownership correction

v7.440 is cut from the exact v7.439 release source. It changes the delivery path for stubborn PDP APE/SafeFrame ads instead of adding another parent-document selector layer.

The v7.435 FULL probes contain the offending `ape_detail_btf_mshop_iframe`, but none of the three captures contains a `CROSS_FRAME_DOM` section. v7.440 therefore does not trust all-frame WKUserScript delivery for those ad documents. Native WebKit frame-tree enumeration now installs a persistent ad stylesheet directly into child-frame page worlds, and a single main-document iframe-load/lifecycle bridge reapplies that stylesheet after lazy frame navigation. The injected stylesheet is inert until ad/product markers appear, so it can survive later hydration without an observer or polling loop.

The child-frame treatment provides OLED floors, light neutral copy, standard gray edges, tamed product media, visible ad-feedback controls, dark neutral carousel controls, and preservation of Prime/star/rating/deal/coupon/promotion colors. Main-document residual ownership also strengthens the `_c2ItY_` lightAds carousel and lifts the probe-confirmed Rufus comparison insight copy from `rgb(86,89,89)` while preserving green insight dots.

The already successful Product image gallery heading, multi-bundle image release, Search sponsored rails, Search sponsored text/floors, and Shop-by-brand treatment remain in place.

No MutationObserver, interval polling, RAF loop, web scroll listener, or recurring hierarchy scan is added. FULL, VIEWPORT, and TRANSITION identities are bumped to v7.440.

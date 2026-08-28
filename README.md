# AmazonDark v7.150~search-video-ad-haul-polish-probe — Search video ad + Haul/Nile polish

## v7.150 delta (direct base: working v7.149)
- Search Nile ingress pills: both `.nile-ingress-pill-button` and its nested `.a-button-inner` now use the established medium gray `#4a4f51` with white text.
- Crazy-good finds / Amazon Haul: the non-image/non-action separator chrome inside `.haul-puis-widget-faceout-container` is forced OLED black, eliminating the bright strip/border under product images without altering product rasters.
- Search product micro-badges: small generic AUI attribute badges outside the Amazon's Choice/Overall Pick lane are transparent with `#ffd814` yellow copy; savings/success chips such as `Save %` are transparent with `#00a650` green copy. Coupon/deal badges and Search filter controls remain excluded.
- Search VIDEO_SINGLE_PRODUCT ad: the exact `s-card-container.s-card-border` wrapper gets the standardized `#494d4d` gray ad border. Product-detail structural floors are OLED black/transparent and internal light dividers normalize to `#494d4d`.
- Search VIDEO_SINGLE_PRODUCT product image: added an exact positive TWB lane outside the video/control subtree, because generic Search TWB intentionally excludes Sponsored descendants.
- Sponsored video controls: the custom glyph paint remains removed. The remaining OLED control-shell leak is consistent with the document-wide `color-scheme:dark` reaching WebKit's UA media chrome. The video is therefore isolated with `color-scheme:light`, and the play/pause/mute pseudo-controls use `all:revert` so author theming no longer owns their visuals. This is intended to restore Amazon/WebKit's stock semi-transparent gray shells with white glyphs.
- Keeps the accelerated-video rendering repair: the real `VIDEO.sbv-video-player-ecx` stays unfiltered; video TWB remains on the separate overlay.
- Existing v7.149 coupon sage treatment remains unchanged.
- Diagnostics remain enabled and now explicitly inventory the VIDEO_SINGLE_PRODUCT card, Nile pills and Haul families.
- No MutationObserver, interval, RAF, scroll listener, or recurring DOM scan is added by these fixes.

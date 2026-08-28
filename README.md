# AmazonDark v7.151~search-alt-video-ad-badge-fix-probe — alternate Search video ad + badge ownership fix

## v7.151 delta (direct base: v7.150)
- Alternate standalone Search video ad (`_c2Itd_*` renderer): adds standardized `#494d4d` card/product-shell borders and owns the lower product-detail structural floors as OLED black.
- Alternate standalone ad TWB: keeps `VIDEO._c2Itd_video_17g-f` compositor-unfiltered, shades the renderer's own full-size `_c2Itd_videoOverlay_1H_Jm`, and adds the exact product raster `img._c2Itd_image_pQREQ` to the normal TWB brightness lane.
- Video controls: removes v7.150's `all:revert` author rule on WebKit media-control pseudos (the source of rectangular control backing boxes). Both known Search video renderers now only receive `color-scheme:light`/`filter:none` on the real video; ordinary control wrappers are kept transparent, and their icon descendants are excluded from AmazonDark's generic glyph filter.
- Limited-time-deal: explicitly restores `DEAL_*` AUI badges to the stock-style deep red `#cc0c39` plate with white text.
- Product micro-badges: retracts the unsafe blanket `.a-badge` rule. Anonymous non-status/non-coupon badges are the yellow transparent attribute lane, including badge-label pseudos so the small white plate can no longer survive. Savings/success markers override the whole matching badge subtree to transparent with `#00a650` green copy. Generic `discount` matching is removed.
- Diagnostics: retains the full v7.150 probe, adds `data-a-badge-type`, `data-a-badge-color`, `data-testid`, and `data-component-type` metadata (still no element text), expands alternate `_c2Itd` card capture, and includes the alternate media/control roots in the control-tree probe.
- No MutationObserver, interval, RAF loop, scroll listener, or recurring DOM scanner is added.

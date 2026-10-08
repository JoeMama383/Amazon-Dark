# AmazonDark v7.595 — probe-backed cumulative changes from v7.594

## Buy Again / Discover page (viewport r7/r8)
- Probe confirmed `#ee-aisles-on-ba-widget-container`, `_YnV5L_` carousel/grid/ASIN owner families, `#ordersSearch`, `#filter-button`, exact item title, image and Add-to-Cart descendants.
- Page, header, search, category, product-grid, and product-card floors OLED. Neutral black text and price white, secondary text medium gray; blue navigation/Prime/selected selection borders, orange stars, red discounts and green savings preserved.
- Add to Cart buttons OLED, white text, existing single gray border. Filter floor gray with white text/chevron. Product images tamed conditionally with existing white-tame preference.

## Separate PDP More Choice A+ comparison module (viewport r6)
- Exact probe owner `#dp .aplus-premium [id^=comparison-table-container-]` including table columns, sticky metric cells and descriptions. Original white table cells OLED black, text white, dividers gray. Blue links and stars preserved. Add-to-Cart controls OLED/white/gray border. Media tamed.

## FULL scanner
- The initial 30,000-view native inventory was delaying the main Web DOM scan. The new generic-Web route discovers currently visible WKWebViews first and begins the existing guarded full Web scroll/DOM stream before the expensive native inventory; exact native Menu/Person still retain their dedicated priority, PDP native scrolling remains disabled, and generic native scroll candidates run afterward.
- No continuous DOM observers or scan machinery added; FULL still requires Amazon to stay foregrounded to finish its walk. Exporting before completion continues to identify incomplete scans as partial.

## VIEWPORT scanner
- All three provided TARs explicitly logged `reason=armed-background-during-full` and a shared 8,000-node root-BFS limit, despite the actual visible page being much deeper. In busy FULL, VIEWPORT now uses an independent read-only native + screen-intersecting Web capture, without touching FULL's nonce or scroll position.
- Replaced the misleading page-prefix BFS in the immediate sampler with dense viewport point hit-testing and local visible siblings, remaining bounded at 1,800 visible records. Exports are marked completed when foreground native + all discovered Web views were captured and no visible child frames are unverified. Genuine errors, saturation, visible child frame gaps, and timeouts remain truthfully marked partial rather than falsely certified.
- FULL/VIEWPORT/TAR trigger/export separation remains intact.

## Regression scope
- 57 normalized recent Python regression tests passed (v7.535–v7.595 group).
- Additional probe-embedding, review CSS, Node JS syntax, C++98 string include, and logo-lint tests passed.
- An attempted wider historical run timed out and cannot be represented as a completed all-suite pass. Theos/iPhone runtime was not available in this environment.

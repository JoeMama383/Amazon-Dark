# AmazonDark v6.0.122

## v6.0.122 — restore chevron first paint + canonical Share

- Removes the v6.0.121 MAB insertion-time JavaScript lane and restores the v6.0.120 filtered observer callback so the product-card chevron no longer regresses to the transient white-disc paint during menu mount.
- Keeps the v6.0.121 custom 16px white Select checkbox/check painter as a documentStart/post-DarkReader CSS owner.
- Replaces path-dependent Share filtering with one canonical white share glyph on the probe-confirmed 20px right-side widget of the final MAB action row. The varying Amazon inner Share painter is visually suppressed, so template/hydration path differences cannot leave it black or double-invert it.
- No new observer, timer, scroll listener, RAF loop, global DOM scan, or native hierarchy walk.


## v6.0.121 — deterministic Select glyph + path-tolerant Share

- Restores the v6.0.115 custom 16px white square/check painter for the chevron-menu Select row.
- Excludes the chevron overlay from the global product-checkbox owner so Select cannot be reclaimed after mount.
- Reuses the existing filtered MutationObserver for a bounded `puis-mab-*` insertion fast path; no new observer, timer, scroll listener, RAF loop, or document scan.
- Share is resolved within the exact Share row and accepts the known `aok-inline-block` / `a-icon-share` paths plus a bounded tiny-painter fallback for product-template variants.
- Menu insertions are terminal for that observer mutation, preventing the overlay itself from waking the heavier checkbox/symbol reconciliation queues.
- Main product-card two-cards/Heart behavior is otherwise unchanged from v6.0.120.


## v6.0.120 — finish chevron-menu Select + Share glyph paint

- Exact production base: v6.0.119; its Search/path fixes, chevron responsiveness, and current two-cards behavior are preserved.
- Fixes the missing **Select** glyph by exempting only the chevron overlay's real `i.a-icon.a-icon-checkbox` from the product-card unchecked-checkbox chrome and whitening the stock sprite directly.
- Fixes intermittent dark **Share** by targeting the v5.440/v5.446-probed 16px `.aok-inline-block` background-image painter without the incorrect `:empty` requirement.
- Save and More-like-this behavior from v6.0.119 are left intact; the submenu cards/+ stays ringless while the main product-card two-cards button keeps its circle.
- The fixes are duplicated in the existing early documentStart and post-DarkReader CSS owners, so they do not wait on a later JavaScript repair.
- No new JavaScript, DOM scan, observer, timer, scroll listener, RAF, event listener, or `:has()` selector was added.

## v6.0.103 — make the More Like This two-cards icon single-paint

- Exact source base: v6.0.101. The unsuccessful v6.0.102 swatch/deal experiment is intentionally not carried forward.
- Fixes the lower-left More Like This two-cards control painting in two visible stages (temporary white/gray child art, then the final cards glyph).
- The finished dark circular chrome + white stacked-cards/plus glyph is now owned in the earliest documentStart CSS and repeated in the post-DarkReader fixes sheet, so first paint and settled paint are identical.
- Amazon's lazy child IMG/SVG/icon painters inside only `.mlt-icon-container` are kept visually transparent; their layout and click target are not removed.
- The existing `sym413` pass now recognizes `.mlt-icon-container` as declaratively owned and skips its old 48-descendant live-art scan after one cleanup.
- No new observer, scroll listener, interval, RAF, timeout, selector traversal, native hook, or image sampler is added.

# AmazonDark v6.0.109

## v6.0.109 — restore Heart scale + match two-cards control

- Production base: v6.0.108.
- Keeps the v6.0.108 stable-shell first-frame Heart ownership that removed the tiny white-dot / delayed-hydration paint race.
- Restores the Heart to the pre-v6.0.108 device-measured scale: the stable `puis-heart-position` shell is naturally 35x35, and its self-contained first-frame SVG is again 35x35 with the same 22px Heart glyph used by v6.0.107.
- Enlarges the dedicated `mlt-icon-container` two-cards control from its prior 32x32 host geometry to 35x35 so its circular control matches that previous Heart size. The stacked-cards glyph itself remains 24x24.
- Both size rules are duplicated in the earliest documentStart sheet and `ADFixesLiteral`, preserving identical first-frame and settled paint.
- No new observer, selector traversal, timer, scroll listener, RAF, `dispatch_after`, timeout, or image sampler.

# AmazonDark v7.426 — PDP OLED and accessory sheet fixes

Based on the exact delivered v7.425 archive; all previous Cart, Medical Care, native header and SWV video fixes are retained.

This release targets the supplied product-page FULL r2 and add-to-cart accessory-sheet FULL r4 probes. Structural PDP containers become OLED; neutral headings, brand links and secondary text become white. Semantic colors, Prime and rating artwork remain excluded. Rufus pill interiors become transparent over their gray controls; the review expander fade is removed. The location pin and report flag are whitened at their image leaves.

The accessory sheet outside #dp gets its own OLED floors, gray controls and light text. The native AXF action bar gets an exact owner for its black button/backing and gray button edge. Existing text-storage commit/draw paths keep its neutral label light. No timers or document-wide runtime scans are added.

Existing configurable media brightness now also covers the observed product/review video thumbnails, multi-brand video leaves, inline product ad images and accessory-sheet images. Image visibility, loading and source attributes are not changed. Undecoded lazy review thumbnails need device verification; this release does not claim to repair a missing image download. Cross-origin ad interiors were absent from the probes, so their existing child stylesheet plus the neutral-color refinement also need device verification.

Validation: 103 Python checks passed, Logos lint passed, probe shell syntax passed, generated JavaScript executed for main/child contexts and brightness 0/45/100. iOS build/link and device rendering were not available here. See VALIDATION-v7.426.md and COMMANDS.md.

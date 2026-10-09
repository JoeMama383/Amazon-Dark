# AmazonDark v7.603 — scoped PDP accent fixes

Source parent: v7.602 `pdp-visual-repair`, unchanged aside from the versioned probe identity and these three fixes.

1. `#climatePledgeFriendlyATF_feature_div #climatePledgeFriendlyBadge .climatePledgeFriendlyProgramName.badgeTreatmentT1`: exactly the 14 px program-label span measured at `rgb(15,17,17)` in both supplied v7.602 VIEWPORT probes, now forced to white. The leaf icon and all unrelated colored badges are unchanged.
2. `.ripers-lrr-badge.a-alert-success`: inherited generic `#dp .a-box` style declarations had hard-forced the stock alert's left 12 px edge and outer 2 px sides to gray `rgb(73,77,77)`. The new injected payload edits **only those two existing neutral border selectors**, excluding `.ripers-lrr-badge`. The actual Amazon success border colors now fall through from its authored CSS; border widths, shape, background and content are untouched. No replacement border is added. The stable frozen legacy floor source remains byte-for-byte intact.
3. `#subscribe-and-save-nudge-container img.sns-nudge-logo-image`: viewport shows a fully loaded 949×953 natural image displayed at 26×26 px. This composite orange Subscribe ring/cart artwork has dark cart ink. The new once-defined SVG paint filter replaces neutral/dark pixels with white while retaining red/orange pixels and source alpha; does not tint the orange ring, move the icon, resize it, fetch it, or change the switch.

Runtime: one-time exact style-node lookup/selector narrowing and one time hidden SVG filter definition. No observers, timers, scrolling, document walker, new visual frames or geometry changes. v7.602 product-bundle/similar-card/reviews CSS retained.

Verification: original uploaded v7.602 viewport TAR members inspected, `test_v7603_pdp_accent_preservation.py` runs as a source regression; production JavaScript syntax and Objective-C++-compatible `gnu++98` JS include verified. Device verification still required for final rendering.

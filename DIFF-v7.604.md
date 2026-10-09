# AmazonDark v7.604 — four captured PDP VIEWPORT scenes

Source parent: v7.603. Probe evidence: supplied archive with v7.602 independent VIEWPORT captures r1–r4.

- r3/r4 product details: preserve the existing `#topHighlights > hr.a-divider-normal.hoc-divider` 1px divider and recolor its top border/background to standard #494d4d; whiten the **existing** `i.a-icon-extender-expand` in the HOC `See more` affordance. No changes to widths/radii/spacing.
- r2 played single-video sponsored unit: unlike a static `<img>`, iOS video may use hardware compositing. Add a pointer-events-none translucent dark alpha overlay to its existing click-through element so playing frames remain subdued; preserve independent player controls above overlay. The sponsored chip now has semi-transparent black .55 alpha rather than the inherited hard .90 treatment.
- r2 video product info: only price typography neutralizes stock dark color; leave Prime blue and checkmark orange unchanged.
- r1 `#sims-substitutes_feature_div_0`: make actual `span.a-price.aok-align-center` and price-number subparts white; recolor actual 32×32 `_cDEzb_mltIngressIcon_` circle floors to gray, borders gray and glyph white. Preserve product images and CTA geometry.
- Preserves all prior v7.603 sustainability, authored border, Subscribe cart, v7.602 visual repair, and prior no-inversion/performance policy. New injection has no DOM walkers, timers, observers or extra scan routine. UI color rules are scoped exclusively to captured owners.

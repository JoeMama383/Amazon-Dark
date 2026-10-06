# AmazonDark v7.570 — hero and Search Prime paint

Based on origin/main 28b36d01 (v7.569). Captured v7.569 viewport evidence identifies three missing paint owners.

- Home canvas-card-cards: apply the existing preference-controlled brightness formula to the image beneath hp-background-image. Sibling feature-overlay text and hotspot controls remain untouched. Declarative rules cover later image loads without recurring scans.
- Search toolbar sf-mobile-filter-hve: replace white fill with #202324, use #e8e6e3 label text, retain the authored outline geometry with a gray outline color.
- Search carousel s-product-image-container.puis-image-overlay-grey: replace the real white background with OLED black. No padding, dimensions, image filters, or semantic paint changes.

Validation: AD_STRICT_VALIDATE=1 sh scripts/validate.sh passes Logos lint and all 223 Python regressions. The added regression parses emitted JavaScript at brightness 1.000, 0.900, 0.684, and 0.420; verifies selector matching and overlay exclusions; and checks Search paint. The existing Objective-C++ preflight includes the new helper dependency. git diff --check passes.

Local checks do not constitute a full Theos build or on-device visual verification. CI compilation and a new viewport/transition capture remain the final verification steps. No probe machinery or keyboard behavior changed.

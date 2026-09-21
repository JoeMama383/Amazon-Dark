# AmazonDark v7.435 — probe-backed PDP/search fixes

Exact parent: v7.433 `universal-crossframe-probe`.

This build uses the v7.433 FULL/VIEWPORT evidence to correct the remaining PDP and Search renderer failures without adding a new runtime engine.

## Fixes

- PDP standalone sponsored ads: OLED child renderer floors, light neutral text, frameless outer APE shell, and visible white-circle/black-`i` feedback glyph.
- `Product image gallery`: fixes the actual `.a-truncate` / `.a-truncate-cut` leaves that the probe reports as `dark-on-dark`.
- `Customers also bought` / multi-product bundle: removes AmazonDark's `brightness(.42)` image filter from the exact p13n bundle product images so loaded images render normally.
- Safety-documents / lower APE carousel: OLED outer shell, no duplicate/white outer border, child ad renderer dark treatment.
- Search sponsored result family: OLED inner containers, no white vertical rails, white neutral copy.
- Search `Shop by brand`: tame the large brand-logo tiles with the standard image brightness treatment.

FULL, VIEWPORT and TRANSITION identities are regenerated to v7.435.

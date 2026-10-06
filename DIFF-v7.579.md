# AmazonDark v7.579 short diff

- Removed the v7.576 Prime-refinement geometry rules that created fake nested rectangles around headers, brand labels, rating labels, footer buttons, and section titles.
- Removed synthetic `1px/2px` borders, synthetic border sides, border radius, display geometry, and custom slider-thumb geometry from the Prime refinement family.
- Kept the refinement family paint-only: OLED floors, white text, gray recoloring of already-authored borders/dividers, and black/white button paint on Amazon's existing button geometry.
- Preserved Amazon's dynamic blue radio/slider states; only the existing slider rail floor is gray and the existing active rail remains blue.
- Added `test_v7579_prime_refinement_paint_only.py` so new geometry cannot be reintroduced into this family.
- Updated the older Prime Deals regression to assert the paint-only successor contract instead of the retired geometry-owning v7.576 rule.
- Bumped package/probe identities to v7.579.

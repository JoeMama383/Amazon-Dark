# AmazonDark v7.609 — Validation

## Verified in source and probe evidence

- Parsed v7.605 VIEWPORT `140931-449-r4`: top photo carousel's 3 visible `<img>` nodes have configured brightness; the review's 235×160 `button.review-image-thumbnail` has `bg=rgb(0,0,0)`, `bgImage=none`, no `<img>` child. Inspected original v7.593 and v7.594 rules that explicitly erased CSS background images on this exact class.
- Parsed the same VIEWPORT sorting popover: `#a-popover-2` with `.sort-order-option`; white wrapper `rgb(255,255,255)`, white/light-gray header and body, original blue selected row border `rgb(33,98,161)`, black close sprite `i.a-icon-close`.
- New `tests/test_v7609_review_photo_bg_and_sort_popup.py`: PASS (restored background-image source rules, authored backgrounds not replaced, sprite treatment, exact popup owner and negative owner, JS syntax, gnu++98 string include).
- Prior targeted suites PASS: v7.607 PDP last-mile, v7.608 review filter, v7.594 review theme, v7.606 Climate Pledge/probe. `scripts/lint-logos.sh`: PASS.
- **Full source validation PASS:** `bash scripts/validate.sh` completed with `python-regressions: OK (266)`, including inherited UI/probe regressions and v7.609 tests. `scripts/lint-logos.sh` passed within the same run.

## Remaining verification

Actual Theos build and on-device view after injection remain required. The probe proves the earlier theme removed authored CSS-backed review images; only a device test can confirm Amazon's remote image resources are present in the current view after those destructive overrides are removed. No remote push performed.

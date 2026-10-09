# AmazonDark v7.608 — Validation

## Completed and PASS

- Parsed the supplied `AmazonDark-v7.605-ui-full-probe-20261009-140338-039-r4.tar` evidence and confirmed the exact review-filter owners:
  - `#reviews-filter-options-view`
  - `#reviews-filter-options-clear`
  - `#reviews-filter-options-apply`
  - `#reviews-media-checkbox`
  - `#star-filter-select`
- Added targeted regression `tests/test_v7608_review_filter_menu_buttons.py` and ran it successfully.
- Re-ran carried-forward targeted checks:
  - `tests/test_v7593_reviews_business_theme.py`
  - `tests/test_v7606_climate_pledge_full_probe.py`
  - `tests/test_v7601_full_scan_partial_diagnostics.py`
- `bash scripts/lint-logos.sh` PASS.
- `python -m compileall src tests` PASS.
- JS syntax and gnu++98 include compilation are exercised by the targeted regression.
- Source ZIP CRC verified and SHA-256 generated.

## Not fully completed

- Full `scripts/validate.sh` suite was not run end-to-end in this environment, so no claim is made for a full historical CI sweep here.
- Actual Theos/iOS build and on-device rendering verification cannot be performed here; run the existing-clone push workflow, then verify the filter menu on phone.

## No remote push was performed

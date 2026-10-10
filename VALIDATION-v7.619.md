# AmazonDark v7.619 — Validation and UI preservation evidence

## Direct failing assertion

`test_v7598_pdp_reviews_ad_followup.py` — **PASS** after version-normalization, using the exact previous failing assertion and the corrected `COMMANDS.md`.

## Tested previous regressions

- v7.590–v7.604 normalized regression tests: **PASS**.
- v7.605–v7.618 normalized regression tests: **PASS**.
- New `test_v7619_release_ui_and_commands.py`: **PASS**.
- `bash scripts/lint-logos.sh`: **PASS**.
- `sh -n scripts/ui-probe.sh scripts/skeleton-probe.sh scripts/performance-probe.sh`: **PASS**.
- v7.613-to-v7.619 JS source-preservation audit: **15 identical source modules**, **no removed source files**, seven post-605 `.js.inc` payloads in sync and injected once.

**Full strict-validation result: PASS — exit code 0.** `AD_STRICT_VALIDATE=1 sh scripts/validate.sh` completed all **276/276 Python regression tests**, as captured in the attached full sequential log (`python-regressions: OK (276)`).

Theos ARM64 packaging is unavailable in the local environment; native compilation must be verified by GitHub Actions. On-device Amazon application behavior cannot be verified from static artifacts.

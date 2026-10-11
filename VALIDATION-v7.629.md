# AmazonDark v7.629 — local validation

- `bash scripts/lint-logos.sh`: PASS.
- `node --check src/ADPerformance7596.js`: PASS.
- `bash -n` for the three diagnostic probe helpers: PASS.
- `python tests/test_v7629_early_webkit_capture.py`: PASS (loading injection guard removed, KVO load-start retries, immediate initial snapshot requested natively, disabled-theme A/B mode, report aggregation).
- `python tests/test_v7628_loading_scroll_telemetry.py`: PASS (5s reports, scroll-start measurement, cumulative document deduplication).
- `python tests/test_v7627_stale_scanner_cleanup.py`: PASS (source scanner cap 8, abandoned Home raster module absent).
- Objective-C++ gnu++98 ARC stub compilation of `ADPerformance7596.inc`: PASS.
- Full `AD_STRICT_VALIDATE=1 sh scripts/validate.sh`: **INCOMPLETE** — terminated after the early historical tests by this environment's execution-time limit; see the attached strict-validation log. No assertion failure was observed before the limit.
- Full iOS Theos rootless compilation and actual WebKit report delivery on device: **NOT VERIFIED**.
- v7.629 changes are confined to opt-in performance diagnostics, report code, associated tests, version metadata and handoff docs. **No Home raster changes or production UI re-theming.**

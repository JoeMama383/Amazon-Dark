# AmazonDark v7.630 — validation

## Passed locally

- `tests/test_v7630_webkit_snapshot_fallback.py`: PASS — simulated missing WKScriptMessageHandler, evaluation-returned numeric snapshot, missing-bridge counters, C++98/ObjC++ stub compile.
- `tests/test_v7629_early_webkit_capture.py`: PASS — injection during loading and immediate snapshot, no production scanner.
- `tests/test_v7628_loading_scroll_telemetry.py`: PASS — cumulative WebKit reports, scroll-response telemetry and deduplication.
- `tests/test_v7627_stale_scanner_cleanup.py`: PASS — deleted Home-raster module does not return; exactly eight production query selectors.
- `scripts/lint-logos.sh`: PASS.
- `node --check src/ADPerformance7596.js`: PASS.
- Three probe helper shell scripts `bash -n`: PASS.
- Source ZIP CRC: PASS.

## Strict suite / device status

`AD_STRICT_VALIDATE=1 sh scripts/validate.sh` passed the initial identity, Logos and 45+ historical regressions, but this local run exceeded the execution limit before completing. The full Theos iOS package build and WebKit document report delivery are **not verified** until GitHub Actions and the on-device v7.630 performance TAR.

## Release scope

Changes are isolated to opt-in performance diagnostic callback snapshots, their offline reporting, regression tests and release identifiers. No production page CSS, OLED floors, native theme hooks, Home raster taming, DOM scanners or universal FULL/VIEWPORT/TRANSITION probe behavior was modified.

# v7.625 validation — performance audit/report

- **PASS** Logos lint.
- **PASS** new v7.625 performance helper/report/static budget regression, using a synthetic prior-version Amazon receipt and one completed 90-second JSON/TAR.
- **PASS** 7/7 normalized targeted historical and current regression tests, including v7.596 performance recorder, Keep Shopping v7.613 media, Alexa v7.622, share-sheet native compilation v7.623, native text final paint v7.624, v7.448 performance invariant, and v7.625 auditor.
- **PASS** `sh -n scripts/performance-probe.sh` and `node --check src/ADKeepShopping7613.js`.
- **PASS** old v7.624 → v7.625 controls/version identity audit.
- **INCOMPLETE** `AD_STRICT_VALIDATE=1 sh scripts/validate.sh` timed out during the early historical suite (55 log lines, last line `Terminated`); cannot claim complete strict validation.
- **NOT RUN** full rootless arm64 Theos / GitHub Actions build, or on-device performance measurement.

The performance test data is **synthetic** and verifies export/report behavior only; it does NOT measure actual iPhone speed.

No UI owner routing, CSS colors, raster/taming pipeline, geometry, probe traversal, settings, or shipping/order logic was changed. The only theme-source edit is the provably redundant `picture img` member removed from an `img` selector in Keep Shopping; all IMG descendants remain matched.

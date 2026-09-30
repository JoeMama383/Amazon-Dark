# AmazonDark v7.532 validation

Release: `7.532~interests-historical-regression-restore`
Direct parent: `7.531~interests-regression-handoff-repair`

## CI regression repaired

v7.531's clean source archive omitted `tests/test_v7529_interests_header_product_text_fix.py`. The phone overlay copied v7.531 over an existing repository that still contained that historical regression, so GitHub CI correctly ran it and rejected the source because the exact v7.529 contextual-menu ownership contract had also been dropped.

v7.532 restores both the historical test file and the exact behavior it protects:
- `#intp-contextual-menu-inline` OLED floor + gray border;
- `_bW9ia_more-icon_1Qpwd` white three-dot raster;
- `_bW9ia_add-icon_21zQ9` white plus raster;
- exact product title/metadata owners;
- exact product-price family;
- existing v7.530 plus/filled-heart/rating/update-sheet/keyboard work remains present.

## Complete source regression run

The exact version-normalization algorithm from `scripts/validate.sh` was applied to a temporary copy containing every source regression in the final tree. The normalized suite was executed in bounded four-worker batches to avoid the sandbox command-duration and memory limits.

Result: **187 / 187 normalized `tests/test_*.py` regressions passed; 0 failed; 0 pending.**

This includes the exact `test_v7529_interests_header_product_text_fix.py` that failed GitHub CI.

## Static validation

PASS:
- `scripts/lint-logos.sh`;
- shell syntax for `validate.sh`, `ui-probe.sh`, and `skeleton-probe.sh`;
- `test_v7532_historical_regression_restore.py`;
- `test_v7480_build_syntax_guard.py`;
- package/Tweak/FULL/VIEWPORT/TRANSITION/SpringBoard version synchronization;
- `layout/DEBIAN/postinst` mode 755;
- `src/Tweak.xm` = 855671 bytes, below the 856000-byte source gate.

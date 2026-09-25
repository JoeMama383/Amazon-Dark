# AmazonDark v7.494 validation

## Scope

v7.494 is a probe-exact correction of the three Your Orders paints that remained unchanged in v7.493.

The supplied `AmazonDark-v7.493-ui-full-probe-20260925-133226-446-r2.tar` identifies the actual computed owners:

- `.yo-mobile-atf` has a **5 px** `rgb(213,217,217)` bottom border. v7.494 keeps the geometry and paints that exact border OLED black.
- `form.search-bar.js-search-bar` has a **5 px** gray bottom border. v7.494 collapses that exact border to the normal **1 px** project-gray line instead of only adjusting descendants.
- `span.product-image__qty` is the quantity badge. It has a transparent fill, light `rgb(213,217,217)` border, and dark `rgb(15,17,17)` text. The prior generic selector could not match it because its class contains none of `badge`, `quantity`, or `count`. v7.494 targets `.product-image__qty` directly.

The v7.493 end-of-orders white text correction, information-tile work, and v7.490 Book transition canvas fix are retained.

## Validation completed

- Repository-normalized Python regression corpus: **167/167 PASS**, executed in bounded sequential batches using the same identity normalization as `scripts/validate.sh`.
- `tests/test_v7494_orders_exact_fix.py`: **PASS**.
- `scripts/lint-logos.sh`: **PASS**.
- `bash -n scripts/ui-probe.sh`: **PASS**.
- `bash -n scripts/skeleton-probe.sh`: **PASS**.
- `bash -n scripts/validate.sh`: **PASS**.
- `sh -n layout/DEBIAN/postinst`: **PASS**.
- `src/Tweak.xm`: **855,973 bytes**, below the repository 856,000-byte gate.
- Package identity: **7.494~orders-exact-fix**.
- Superseded v7.490-v7.493 Your Orders handoff regressions are absent from the clean source tree.

The one-shot strict validator was also started and produced only passes before this execution environment timed out; the same normalized 167-test corpus was then completed sequentially in bounded batches with no failures.

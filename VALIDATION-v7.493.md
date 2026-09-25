# AmazonDark v7.493 validation

## Reproduced CI failure mechanism

The clean v7.492 source tree passes the normalized regression corpus, but the phone handoff command used `cp -a "$AD_STAGE/." .` on top of the existing Git checkout. That operation does **not delete tracked files that disappeared from a newer source package**.

The last known working v7.490 tree contains `tests/test_v7490_your_orders_theme.py`. v7.491/v7.492 replaced that handoff regression with a newer test, but the overlay push command left the old v7.490 test in the Git checkout. That stale test contains the now-invalid assertion that `_timely-reminders-information-tile_style_tileContainer` must **not** be themed.

The failure is reproducible against v7.492 by adding that stale tracked test back and applying the exact `scripts/validate.sh` version normalizer. It fails at:

```text
assert '[class*="_timely-reminders-information-tile_style_tileContainer"]' not in J
```

That assertion directly conflicts with the requested v7.491 blue Prime/info-tile fix. This explains why the clean package validation could pass while the pushed GitHub tree still failed CI.

v7.493 fixes the handoff in two layers:

1. The PUSH command replaces the canonical source directories (`src`, `scripts`, `tests`, `layout`, `prefs`, `.github`) instead of overlay-copying them, so deleted/superseded tracked tests are actually removed and `git add -A` records the deletions.
2. `scripts/validate.sh` now rejects the known superseded v7.490/v7.491/v7.492 handoff test filenames immediately. A future accidental overlay therefore fails on the phone before it can be pushed.

## Your Orders UI follow-up

The supplied FULL probe gives an exact owner for the dark footer message:

```text
DIV#your-orders-mobile-content-container__end-of-items-divider
  > SPAN.a-size-small.a-color-base
```

The probe reports that span as `rgb(15,17,17)` on the OLED page. v7.493 applies white neutral text only to that exact owner:

```css
#your-orders-mobile-content-container__end-of-items-divider > .a-size-small.a-color-base {
    color:#fff!important;
    -webkit-text-fill-color:#fff!important;
}
```

The v7.491/v7.492 Orders follow-up remains intact: full blue Prime/info-tile taming, no extra tile borders, OLED thick divider treatment, normalized search-bar seam, gray/white quantity bubble, tamed media, and preserved blue search magnifier/dynamic colors. The v7.490 Book `#a-white` transition fix is unchanged.

## Validation completed

- Reproduced the stale-v7.490-test failure against v7.492 using the exact validator normalization: **FAIL as expected** on the obsolete information-tile assertion.
- Verified the new stale-test gate rejects that exact file before the Python corpus begins: **PASS**.
- Exact normalized Python corpus for v7.493: **167/167 PASS**, run sequentially in bounded batches (1–20, 21–40, 41–60, 61–80, 81–100, 101–120, 121–140, 141–160, 161–167).
- `tests/test_v7493_orders_endtext_ci_repair.py`: **PASS**.
- `tests/test_v7480_build_syntax_guard.py`: **PASS** (retains the Objective-C++ guard for the v7.479 compiler failure).
- `scripts/lint-logos.sh`: **PASS**.
- `bash -n scripts/ui-probe.sh`: **PASS**.
- `bash -n scripts/skeleton-probe.sh`: **PASS**.
- `bash -n scripts/validate.sh`: **PASS**.
- `sh -n layout/DEBIAN/postinst`: **PASS**.
- Decoded `src/ADNewMenus7482.js.inc`: `node --check` **PASS**.
- Decoded `src/ADReturnsTheme7480.js.inc`: `node --check` **PASS**.
- `src/ADNewMenus7482.js.inc` as adjacent literals under C99: **PASS**.
- Same include under GNU++98: **PASS**.
- `src/Tweak.xm`: **855,981 bytes**, below the 856,000-byte repository gate.

The GitHub connector's repository/Actions methods are not exposed in this chat session, so this report does not claim direct access to the private live run log. The CI failure mechanism above was reproduced from the exact repository workflow, the exact previous/new test trees, and the same normalization code used by GitHub Actions.

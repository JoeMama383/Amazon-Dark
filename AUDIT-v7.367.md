# AmazonDark v7.367 — Subscribe & Save renderer parity audit

## Direct base

`7.366~cart-empty-caption-fix`.

## Probe-backed diagnosis

Three v7.366 FULL captures establish that this was not an intermittent late-paint race. Amazon is serving two structurally different Cart Subscribe & Save renderers.

- **Bad OFF, r1 (11:37):** `sns-mobile-cart-improvements-container sns-upsell-zero-base` inserts `span.a-declarative` between the container and `.a-box`. The card computed as `rgb(255,255,255)` with `rgb(213,217,217)` border. The OFF `.a-switch` itself was already correct at `rgb(136,140,140)` and its thumb was white.
- **Bad ON, r2 (11:39):** the same `sns-upsell-zero-base > span.a-declarative > .a-box` path remained white. `.a-switch-row.a-active .a-switch` correctly computed Amazon blue `rgb(33,98,161)`, proving the two-stage switch-state rule was not the problem.
- **Correct, r4 (11:45):** `sns-mobile-cart-improvements-container sns-upsell-base-and-tiered` owns `.a-box` directly. The existing AmazonDark direct-child selector matched it and computed `rgb(48,51,53)` (`#303335`) with `rgb(116,122,124)` (`#747a7c`) border.

The v7.366 production CSS targeted only:

`#sc-page-container .sns-mobile-cart-improvements-container > .a-box`

Therefore the zero-base renderer was outside ownership solely because of its extra declarative wrapper.

## v7.367 correction

The existing Subscribe & Save card rule is extended to one additional exact path:

`#sc-page-container .sns-mobile-cart-improvements-container > span.a-declarative > .a-box`

and the corresponding wrapped `.a-box-inner` path.

No state machine, replacement control, observer, timer, or renderer detection is added. Existing switch ownership is unchanged:

- OFF track: `rgb(136,140,140)`
- ON track: `rgb(33,98,161)`
- thumb: white

A Chromium renderer harness verifies the direct renderer, wrapped OFF renderer, and wrapped ON renderer all resolve to the intended card floor/border while preserving those switch states.

## Preservation

- v7.366 empty-Cart caption fix retained.
- v7.365 same-day progress/text and Sustainability sheet fixes retained.
- Universal FULL/VIEWPORT architecture retained; only operational output identity advances to v7.367.
- `src/AmazonDarkSB.xm`, `src/ADSkeletonProbe7339.js.inc`, `Makefile`, and `.github/workflows/build.yml` remain byte-identical to v7.366.
- Tweak production mechanism counts remain 0 for `MutationObserver`, `setInterval`, `requestAnimationFrame`, web scroll listeners, and `querySelectorAll`.

## Validation

- All 21 Python regression scripts: PASS.
- New `test_v7367_sns_zero_base_wrapper.py`: PASS.
- `scripts/ui-probe.sh` and `scripts/skeleton-probe.sh` syntax: PASS.
- Logos lint: PASS.
- Project plists: PASS.
- Chromium direct/wrapped OFF/wrapped ON CSS harness: PASS.
- Diff trailing-whitespace check: PASS.
- Local Theos compile/package cannot be claimed in this runtime because `/makefiles/common.mk` is absent; GitHub Actions/on-device Theos remains authoritative.

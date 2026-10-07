# AmazonDark v7.590 validation

Target: `7.590~cumulative-ui-universal-full-shop-show`

## Final-source validation

- `scripts/lint-logos.sh`: **PASS**
- `bash -n scripts/ui-probe.sh`: **PASS**
- `bash -n scripts/skeleton-probe.sh`: **PASS**
- package / tweak / FULL+VIEWPORT helper / transition helper / launch-probe identities synchronized to `7.590`: **PASS**
- current cumulative v7.590 regression: **PASS**
- historical/current normalized Python regression corpus: **243 / 243 PASS**

The 243-test normalized corpus was run against the **final source** in four bounded batches to prevent compiler-heavy historical fixtures from starving each other in the sandbox:
- batch 1: 61 / 61 PASS
- batch 2: 61 / 61 PASS
- batch 3: 61 / 61 PASS
- batch 4: 60 / 60 PASS

## Contracts covered by the regression corpus

The passing corpus includes the existing contracts for cold launch, checkout, Cart, Search, Person, Returns, Menu, PDP, SafeFrames, transition capture, FULL/VIEWPORT transport, current-session TAR export, C99 / gnu++98 payload compilation, probe route arbitration, no-recurring-work guards, medical/auth follow-ups, Prime transition/divider behavior, PDP coupon/media ownership, Orders/review ownership, and the new renderer-neutral FULL / Shop the Show contracts.

## v7.590-specific verification

The v7.590 regression verifies:
- all post-v7.585 medical/auth selectors remain in the cumulative source;
- v7.587 One Medical/auth bottom-sheet owners remain;
- v7.588 PDP coupon/package-info/fullscreen-thumbnail owners remain;
- v7.589 compact Orders magnifier and Your Review owners remain;
- Shop the Show exact RN/AppCX identifiers and media families are present;
- product raster crop uses `UIViewContentModeScaleAspectFill` only inside the exact Shop the Show product families;
- Shop the Show media uses the existing TWB overlay/strength;
- FULL contains WebKit scanning plus generic UIKit/React Native foreground-scroller discovery;
- foreground native ownership uses UIWindow hit-testing to reject retained/covered roots;
- Menu/Person exact walkers remain fallback-only after universal native discovery;
- no recurring observer/timer/RAF production mechanism was introduced by v7.590.

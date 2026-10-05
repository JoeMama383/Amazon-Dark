# v7.565 validation

Baseline: origin/main 7dd4ad9e, v7.564 compiler fixture repair.

Evidence: v7.564 VIEWPORT 075324-073 (Home countdown), 082928-544 (Health sheet), 083321-882 (Grocery sheet), with IMG_7484/7485/7486 screenshots.

The countdown uses `_hve-countdown-timer_style_stripeTimerDigit__` rather than the older Timer-Numeric class. The native sheets share `sheet-view` / `sheet-inset-view` ancestry, with exact Health pill identifiers or Grocery nearby-store text as witnesses. Existing AppCX/Rufus retained trees are not discovery targets.

Validation includes the full strict regression suite, exact native helper Objective-C++ syntax preflight, production premultiplied raster color/alpha execution, and finite discovery / cache / no-geometry contracts. Local Clang is provided by the Zig distribution; the UIKit syntax fixture is not a substitute for the native Theos SDK build. Device rendering, revisit, and preference-toggle checks remain pending.

Result: lint-logos OK; strict Python regressions OK (218), including the new service-sheet test. The image cache also reuses the transformed result when an existing owner restores the same authored image.

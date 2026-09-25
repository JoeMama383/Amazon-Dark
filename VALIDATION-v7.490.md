# AmazonDark v7.490 validation

## Scope

v7.490 combines two probe-backed corrections on top of v7.489:

1. **Your Orders** (`section.your-orders-mobile-content-container.aok-relative.js-yo-container`)
   - OLED page/header/card floors.
   - `Your Orders` and `Purchase history` neutral headers -> white.
   - `Past three months` -> secondary light gray.
   - Search control -> dark neutral; authored blue magnifying-glass raster preserved.
   - Filter/touch-link chevron -> white.
   - White Buy Again / Return requested reminder cards -> OLED with project gray edges.
   - Purchase-history cards/media planes -> OLED with gray edges and white neutral copy.
   - Product/ad rasters -> tamed; authored blue informational-card/link colors are preserved.

2. **Book Details → See more transition**
   - The expanded v7.489 transition capture was reproduced twice back-to-back.
   - Native `AMIWebViewController` root and nested `WKWebView` are already black during both reproductions.
   - The actual bright plane is a DOM `DIV#a-white` in the same document.
   - First reproduction: the probe records `#a-white` at 430 px wide with heights 839/779/813 px from uptime ~104704.174 through ~104705.072, painted `rgb(255,255,255)`.
   - Second reproduction: the same `#a-white` appears again from uptime ~104710.488 through ~104711.399 with the same full-width white paint.
   - v7.490 adds one document-start paint-only rule: `#a-white{background:#000!important;background-color:#000!important;box-shadow:none!important;}`.
   - No width, height, display, opacity, transform, animation, transition, position, timing, or hierarchy mutation is added for the transition canvas.
   - The existing black `_UIParallaxDimmingView` animation is therefore left intact; the underlying temporary white canvas becomes OLED for both presentation and dismissal stages.

Expanded AMI lifecycle diagnostics remain available in TRANSITION for confirmation after installation.

## Validation completed

- `tests/test_v7490_your_orders_theme.py`: PASS.
- `tests/test_v7480_build_syntax_guard.py`: PASS (retains the exact Objective-C++ syntax guard for the v7.479 compiler failure).
- Version-normalized recent regression chain `v7.481`, `v7.482`, `v7.483`, `v7.486`, `v7.487`, `v7.488`, `v7.489`, `v7.490`: PASS.
- `scripts/lint-logos.sh`: PASS.
- `bash -n scripts/ui-probe.sh`: PASS.
- `bash -n scripts/skeleton-probe.sh`: PASS.
- `bash -n scripts/validate.sh`: PASS.
- `sh -n layout/DEBIAN/postinst`: PASS.
- Decoded `src/ADNewMenus7482.js.inc`: `node --check` PASS.
- Decoded `src/ADReturnsTheme7480.js.inc`: `node --check` PASS.
- Both modified/retained JS includes compile as adjacent literals under C99 and GNU++98: PASS.
- `src/Tweak.xm`: 855,979 bytes, below the repository 856,000-byte gate.

The complete historical Python regression corpus is too slow for one uninterrupted run in this execution environment; a parallel attempt was invalid because several historical tests share temporary resources, and a sequential attempt exceeded the environment wall-clock window. No failure was observed in the relevant current-version regression chain above. GitHub Actions remains the authoritative full Theos compile/link/package result.

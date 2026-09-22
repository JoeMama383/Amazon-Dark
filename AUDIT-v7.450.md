# AmazonDark v7.450 audit — PDP read-only FULL

## Direct parent

`v7.449~full-probe-nonblocking` (`AmazonDark-v7.449-full-probe-nonblocking-source.zip`, SHA-256 `6ca3e5366c9a63f590c201eb480f1ecb0d9db88e1ec928514b5f27058eae4887`).

## Why the earlier diagnosis was wrong

The failure is renderer-specific, not evidence that the generic FULL engine is broken: the user reports FULL works on the other menus and fails on Product Detail. Historical v7.435 captures provide the control. Before any active sweep, the three PDP captures already serialized 7,530 / 7,546 / 9,074 mounted nodes with document heights 11,341 / 11,341 / 13,076 px. After the sweep drove the product WebView, all three reported a 779 px final WebKit content height.

That makes scroll mutation itself the product-specific failure boundary. Improving the scheduler around the same mutation cannot solve it.

## Correction

- Native URL product routes are classified before JavaScript: `/dp/`, `/gp/product/`, `/gp/aw/d/`.
- Exact `#dp` is a fallback classifier for equivalent product renderers.
- PDP presence is preflighted before any FULL WebView is scanned; once detected, every WebView in that capture is serialized read-only so auxiliary WebViews cannot be driven first.
- PDP FULL executes the existing cooperative full DOM serializer without changing scroll state.
- A passive delayed catch-up captures newly mounted nodes already present after hydration.
- PDP FULL never calls the Web scroll-command path or nested-owner sweep.
- Once a PDP is present in the FULL session, generic native scroll discovery/sweeps are skipped as well.
- Initial/final native hierarchy snapshots remain read-only.
- Non-PDP FULL is unchanged from v7.449.

## Production/performance boundary

Production theme code is unchanged except release identity. No production observer, timer, RAF loop, scroll listener, polling loop, or recurring traversal is added.

## Device boundary

Static/source validation can prove that the PDP branch contains no scroll mutation and that the inherited contracts remain present. It cannot prove on-device responsiveness; the installed GitHub Actions build remains the device test.

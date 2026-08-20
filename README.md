# AmazonDark

AmazonDark is a rootless iOS tweak that applies a dark theme to the Amazon Shopping app while preserving Amazon-owned imagery, layout, interaction, and native component geometry.

## v6.0.160 — optimized recovery baseline

This release returns to the compact v6.0.154–v6.0.158 architecture instead of the expanded v6.0.152 rollback, while keeping the rendering safeguards learned from the later failures.

### Performance architecture retained

- Two injected `MutationObserver` instances remain; there are no web scroll listeners, recurring intervals, or `requestAnimationFrame` loops.
- The native-ad watcher stays consolidated into the bounded contrast observer.
- The broad contrast `querySelectorAll('*')` collection remains replaced by a capped `TreeWalker`.
- Checkbox stale-marker cleanup remains one selector pass instead of four document scans.
- TWB installation remains idempotent, preventing repeated media/listener installation and repeated initial media passes.
- Home seasonal/mosaic runtime work remains gated away from PDP, Search, Cart, and auth documents.
- Offscreen retained WKWebViews remain skipped when fully detached.
- Recycled React/Fabric Person-card ownership remains self-invalidating so stale raster suppression cannot blank reused Home/Person content.
- Diagnostic/probe/report-file code, temporary 120 Hz verification code, and JIT logging remain removed.
- SpringBoard preference reads remain cached and event-driven.

### Dark-background reliability correction

The prior optimized recovery could still leave a visible document light when a WKWebView was already bootstrapped but Dark Reader needed to be re-enabled after remounting.

v6.0.160 changes that without restoring the old heavy TWB fallback:

- `didMoveToWindow` bootstrap now re-applies the existing Dark Reader owner when `__AMZDARK_LOADED__` is already present instead of returning immediately.
- Transition-mounted WKWebViews are eligible for recovery as soon as they have either a `window` or a `superview`; fully detached retained controllers remain skipped.
- All three existing appearance checkpoints can submit bounded WebView recovery again. Because TWB is now idempotent, those checkpoints do not stack the old full TWB payload, media handlers, or 420-item initial pass.
- Native view-tree sweeps remain limited to the existing first/last checkpoints.

This keeps the compact optimized architecture while closing the timing gap that produced light Home/Search/PDP surfaces after the earlier reduction.

### Preserved theming

Dark Reader/bootstrap styling, Tame Light Backgrounds, Home/Search/PDP repairs, Person-tab gray borders, neutral search border, Sign Out/Cancel surfaces, unsigned-Cart credit treatment, sign-in footer first paint, checkbox/Heart/cards/dot ownership, Sponsored text/info badge treatment, video/voice handling, splash cover, JIT preference, and 120 Hz preference remain present.

## Build

The top-level Theos project builds `AmazonDark`, `AmazonDarkSB`, and the `ADPrefs` Settings bundle.

Dark Reader is installed once at `/Library/Application Support/AmazonDark/darkreader.js`; rootless packaging maps this to `/var/jb/Library/Application Support/AmazonDark/darkreader.js`.

```bash
make clean package
```

## Project

Maintained as `JoeMama383/Amazon-Dark`.

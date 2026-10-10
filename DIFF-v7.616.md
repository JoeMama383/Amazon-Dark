# AmazonDark v7.616 — universal probe transport diagnostics and fallback

Parent: v7.615 full source.

- `scripts/ui-probe.sh` now determines the real installed package version (`dpkg-query`) and looks for **current installed-version** states instead of assuming an unbuilt checkout version is running. Preserves exact mode-specific TAR exports and no historical bundling.
- Discovers app Documents directly through current UI `.state` and screenshot `.receipt` files even if the old startup JSON or the container metadata isn't discoverable. A screenshot failure now reports installed/helper mismatch, current target count and matching probe receipt, rather than a misleading silent 'no v7.xxx state'.
- Adds a bounded, one-shot `arm full` foreground fallback for cases where iOS screenshot callback does not arrive. Plain `arm` is still the next-background VIEWPORT arm. Both FULL triggers run the **same** universal native/WKWebView/child-frame scan on any route; neither is route-specific.
- On screenshot, writes a tiny `ui-trigger.receipt` *before* scanning so export can distinguish OS screenshot delivery from an absent live tweak. It contains only version, time, enabled state and foreground state.
- Adds exact compiler-error extraction and a failure-only artifact in GitHub Actions so the underlying `error:` diagnostics are available even when ARC retain-cycle warnings dominate the tail.
- Adds fixture-backed shell regression tests for installed-v7.615/helper-v7.616 and installed-v7.616/helper-v7.616, missing metadata, TAR manifest, and no stale-version export.
- Preserves the v7.615 UI, all prior theming scripts, unchanged FULL walker coverage and the three separately exported TAR probe families.

On-device complete FULL behavior, iOS compilation, and any Your Orders UI theme remain unverified until compiled/tested; the screenshots do not establish a successful v7.615 installation.

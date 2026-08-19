# AmazonDark

AmazonDark is a rootless iOS tweak that applies a dark theme to the Amazon Shopping app while preserving Amazon-owned product imagery, branded artwork, layout, interaction, and native component geometry.

## v6.0.154 — runtime consolidation and source cleanup

This release is built directly from **v6.0.152**. The v6.0.153 bottom-navigation experiment is not included. The visual/theming target is therefore v6.0.152; this pass focuses on reducing work around that target rather than changing it.

### Runtime cleanup

- Consolidates the native-ad DOM watcher into the existing bounded contrast observer, reducing the injected web observer count without removing native-ad marking, video-control protection, or contrast recovery.
- Replaces the broad `querySelectorAll('*')` contrast collection with a capped `TreeWalker`, so a document pass stops when its existing element budget is reached instead of first materializing every descendant.
- Collapses four checkbox stale-marker document scans into one selector pass and removes checkbox/symbol/dot counters that existed only for diagnostics.
- Removes the dormant standalone-ad probe/exporter, its launch file initialization, and its background DOM dump path.
- JIT now exits before dispatch/syscall work when disabled. When enabled, it retains the existing broker request path but no longer writes a launch report file or performs report-only follow-up work.
- Removes the temporary 120 Hz verification display link and report-file path. The actual 120 Hz preference, display-link ownership, frame-rate hooks, and restore logic remain intact.
- SpringBoard preference state is cached and refreshed by the existing Darwin preference notification instead of synchronizing preferences on each scene check.
- Removes file logging from the SpringBoard companion and Settings bundle.

### Source and package cleanup

- Factors repeated first-paint/post-Dark-Reader CSS into shared string macros while preserving the emitted CSS token stream at both use sites.
- Removes obsolete probe code, unused SpringBoard cover code, stale PreferenceBundle source/layout copies, and the duplicate installed Dark Reader payload. The canonical bundled `Resources/darkreader.js` remains authoritative.
- Replaces version-by-version source commentary with concise subsystem headers and removes stale build archaeology from active source files.
- Keeps the existing PreferenceLoader entry and builds the Settings bundle from the single top-level Theos target.

### Preserved theming

The v6.0.152 theming paths remain in place, including Dark Reader/bootstrap styling, native dark-theme hooks, Tame Light Backgrounds, Home/Search/PDP repairs, Person-tab raster borders, the neutral search border, Sign Out/Cancel surfaces, unsigned-Cart Visa treatment, sign-in footer first paint, checkbox/Heart/cards/dot ownership, video controls, Sponsored text and 12 px info badge treatment, splash cover, JIT toggle, and 120 Hz toggle.

The existing `:has()` selector architecture is intentionally retained. Earlier code review identified it as a possible style-recalculation cost, but replacing it with mutation-time element marking would change ownership architecture rather than merely compress it; that is outside this theming-preserving cleanup.

## Build

The project is built with Theos for rootless iOS 15+ targets. The top-level `Makefile` builds:

- `AmazonDark` — Amazon app theming/runtime component.
- `AmazonDarkSB` — SpringBoard launch-cover and optional JIT-broker companion.
- `ADPrefs` — Settings preference bundle.

Dark Reader is packaged from `Resources/` into `AmazonDark.bundle` by the Theos resource target.

```bash
make clean package
```

GitHub Actions is also configured to compile/package the source tree.

## Install / activate

Install the generated rootless `.deb`, then force-quit and relaunch Amazon. Preference changes can be made under **Settings → AmazonDark**; use the Settings pane's Respring action when needed.

## Project

Maintained as `JoeMama383/Amazon-Dark`.

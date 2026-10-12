# AmazonDark v7.634 — validation

- Full source regression suite: **294/294 passed** (`scripts/validate.sh` with CSS dependencies and Clang available).
- New runtime tests: existing/nested Books roots, open/closed roots, unrelated-component passthrough, original exception behavior, shared stylesheet/fallback, taming off/on, repeat injection.
- New selector/cascade fixtures: 21 captured paint owners plus selected colors/borders, stars, glyphs, toggle thumbs, unrelated pages, and a geometry/visibility mutation guard.
- Exact JavaScript/include byte fidelity and CSS mirror checks passed.
- Logos-generated Tweak, SpringBoard, Preferences and ADSponsored code passed arm64 iOS 17 syntax checking with the iOS 16.5 SDK; Objective-C++ uses gnu++98. Tweak retains six existing probe block-retain warnings. Other compilation units produced no diagnostics.
- All 22 TAR inventories reviewed (5,755 nodes after deduplication within each capture). Full per-capture mapping is in COVERAGE-v7.634.md.
- Existing native/web code is unchanged after version normalization, except registration of the new module. Search/PDP fast paths and the portable cache regression passed.
- Static production census: no new MutationObserver, interval, animation-frame loop, scroll listener or TreeWalker. One bounded Books late-root catch-up changes querySelectorAll source occurrences from 8 to 9; this is not a runtime benchmark.
- Shell helpers and JavaScript syntax checks passed. Archive CRC and source/package version checks passed.

## Limits

This is a source release, not a locally linked/signed .deb. The existing GitHub Actions workflow builds the installable package after the manual push. No device was connected: the new rendering, actual input latency and on-device probe behavior have not been measured. Supplied probes are from v7.633 and their cross-frame coverage is best-effort/unverified, even where the run reports completed. No screenshot comparison is claimed.

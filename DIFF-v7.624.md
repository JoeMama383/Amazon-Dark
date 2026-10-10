# AmazonDark v7.624 — Alexa plus-menu black text final-paint repair

Base: v7.623 `alexa-ci-compile-repair` source.

- `src/Tweak.xm`: integrate existing exact Alexa sheet owner into `ADOwnReactText7271` mounted-text reapplication, native RCTTextView post-commit and final `drawRect:` paths, and paragraph mount/layout paths.
- `ADAlexaRepaintMountedText7624`: exact scope of the Amazon `plus-menu-modal-container` or confirmed microphone `sheet-view` and `RCTTextView`. Preserve authored blue New badge, whiten neutral black text via existing `ADMenuLightStorage7255`; no global overrides, no new loops, no new borders or image filters.
- `THEMING-CONTRACT.md`: durable project acceptance rule for black text -> white, OLED floors and semantic paint preservation. Added sanitized probe fixture and v7.624 regression test.
- Update only release/probe version identity and push/probe handoff to v7.624. All earlier scoped orders, advertising, shipping, Alexa and feedback modules are retained; Home raster untouched.
- Audit: the user-supplied 7.623 screenshot-triggered FULL export is a Search results WebKit document, **not** the Alexa plus menu. The correct exact native r4 Alexa modal owner is in the earlier 7.620 VIEWPORT probe; it clearly records the failing near-black 17pt React title under automations-mode-button.

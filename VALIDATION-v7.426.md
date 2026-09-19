# v7.426 validation

- 103 available Python regression scripts passed, including current/direct-parent probe handoffs.
- Logos lint passed after fixing nested %orig arguments.
- Both probe helper scripts passed sh -n.
- Node execution of emitted PDP JavaScript passed: repeated injection updates one stylesheet, unrelated child contexts remain untouched, product children receive the child sheet, media strength endpoints and midpoint emit valid JavaScript.
- The existing clang linkage regression was not run because clang is unavailable. No iOS SDK/Theos was available, so compilation/linking and phone rendering are pending.
- Probe evidence: v7.424 FULL r2 (PDP), FULL r4 (accessory sheet). Both supplied main DOM snapshots; no cross-origin ad child DOM was captured.
- Blank review thumbnails include naturalWidth/naturalHeight zero with incomplete lazy loading. No source rewrites, forced visibility, tracking-pixel exposure or speculative eager loading were introduced.

Device checks: native sticky button and backing; PDP/review OLED floors; semantic stars/Prime/discount colors; report flag/location pin; full accessory sheet including scroll; image/video brightness; standalone iframe ad interiors. Capture FULL for the product page and again for the open accessory sheet after installing this release.

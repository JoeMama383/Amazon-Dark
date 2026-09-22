# AmazonDark v7.445 — probe and PDP transition hardening

Exact direct parent: **v7.444~pdp-proven-media**.

This release preserves v7.444 theming and addresses the diagnostic failures seen on the Product Search / PDP interface plus the fresh Search -> PDP transition trace.

- FULL screenshots are no longer consumed by an armed TRANSITION recorder. A screenshot can feed transition evidence and still start the universal FULL capture.
- FULL now follows lazy-growing WKWebView content to a stable bottom instead of treating the first temporary content height as the end. It requires three stable bottom holds, records content growth, restores the original offset, and has a 4-second JavaScript callback timeout.
- The generic native-scroll phase is bounded to the four highest-value candidates, 32 vertical / 16 horizontal steps, and smaller subtree snapshots so the diagnostic pass cannot spend minutes walking unrelated native scrollers after the PDP Web sweep.
- FULL and VIEWPORT use independent state receipts and explicit exports: `export full` and `export viewport`. Each export contains exactly one completed current capture in its own ZIP.
- TRANSITION export is current-arm/current-version only. Historical v7.x recordings are never bundled into a new archive.
- Transition traces now record logical image size, image scale, and backing CGImage pixels separately.
- The exact `IESSkeletonView -> AWLoadingIndicatorFullScreenModalBar` Search -> PDP image owner is matched using logical/scale-normalized geometry. This covers the fresh v7.444 460x1036-point trace without depending on @1x backing pixels, while retaining the narrow native owner chain and one-time image transform.

No production MutationObserver, polling loop, requestAnimationFrame loop, Web scroll listener, or recurring hierarchy scanner was added. The expanded walking remains opt-in probe-only work.

Still outstanding for a later probe-backed pass: the white medium standalone-ad interior, the separate medium ad family's outer duplicate square border, the compact top-ad title/sponsored-info treatment, and verification of the large Easter/media family. v7.445 intentionally does not broaden those ad selectors without a reliable post-fix FULL capture.

See `COMMANDS.md` for the phone workflow.

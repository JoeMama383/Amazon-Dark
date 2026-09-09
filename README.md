# AmazonDark v7.376 — warm/app-switcher non-interference

Direct parent: **v7.375~checkout-prepaint-snapshot-hydration**.

This is a surgical lifecycle correction. All v7.375 checkout prepaint, duplicate-presentation, BYG hydration, back-arrow, ADTWBJS factor/shade, and CI fixes remain.

- **No app-switcher cover.** The v7.375 black `AmazonDarkWarmSnapshotCover7375` workaround is removed completely. UIKit once again snapshots the already-themed live Amazon scene.
- **No warm splash suppression.** The inherited v7.307 `gADOrdinaryWarmResume7307` / hidden+alpha state machine is removed. AmazonDark no longer hides or reveals AXU/Tez based on background/foreground state.
- **Root-cause backtrack.** v7.335/v7.336 had already established the good v6.0.185 contract: no switcher owner and no warm hierarchy mutation. The later v7.337 launch rebase onto v7.307 accidentally reintroduced warm suppression, and v7.350 explicitly retained it. v7.376 removes that architectural regression while preserving the later cold-splash seal.
- **Cold splash remains dark.** If Amazon actually presents `AXUSplashScreenViewController` or `TezBaseSplashScreenViewController`, the v7.350 exact-controller black/logo seal still themes its pixels, but Amazon/UIKit alone own visibility, timing, and dismissal.
- **No new timers/observers/scanners.** This release removes lifecycle mutation code rather than adding another workaround.

---

# AmazonDark v7.375 — checkout prepaint / warm snapshot / BYG hydration

Direct parent: **v7.374~byg-price-checkout-first-paint**  
Parent `src/Tweak.xm` SHA-256: `9b320db93e2bdae3b416e8ca0958821bc54e1fcc6b6048caf2694db1b302c743`

This is a narrow stabilization release. It preserves the working v7.374 menu, checkout-body, BYG price, dynamic Prime/red/green/blue, loader, press-state, and quantity-control styling while addressing the remaining timing defects.

- **Checkout transition first paint:** the incoming `AMSModalLayoutFullScreenViewController` now primes its OLED root/navigation appearance before UIKit composites the presentation. The direct `_UIBarBackground` image leaf is hidden by structural modal ownership, and the exact Amazon tan `rgba(0.929,0.733,0.506,1)` transition plane is claimed even when its model height is zero.
- **Duplicate checkout pass:** v7.374's `UINavigationBar` / `_UIBarBackground` checkout `layoutSubviews` reassertions are removed. Ownership is event-driven before the transition instead of mutating the hierarchy during the animation. A state/identity guard only rejects a provably redundant second request from the same presenter while the first checkout is still live; there is no time debounce.
- **Checkout back arrow:** all checkout `UINavigationBarAppearance` states and late tint writes are scoped to OLED + white bar-button/back-button tint.
- **Warm app switcher/resume:** a per-primary-window black snapshot cover is installed synchronously when the app backgrounds and is removed at `DidBecomeActive`, eliminating the stale teal task-switcher/warm-entry plane without adding another modal.
- **Missing BYG `+`:** no fake control is created. At normal load/pageshow, one exact sparse-card signature can trigger one synchronous layout/carousel/resize nudge so Amazon's own dense-grid renderer gets one chance to insert the real ATC subtree. No reload, MutationObserver, timer, RAF, or recurring scanner is used.
- **TWB video overlays:** fixes Claude's confirmed `factor`/`shade` swap in the three `rgba(0,0,0,alpha)` search/video overlay slots. `ADStandalonePaintJS7104` was audited position-by-position and remains correct.
- **Release validation:** the phone-safe push flow always runs `scripts/lint-logos.sh` and runs the Python regression suite when `python3` is installed. GitHub Actions explicitly installs Python and runs `AD_STRICT_VALIDATE=1 sh scripts/validate.sh`, so all 28 Python regressions are mandatory before packaging. The Playwright-based `.cjs` render fixtures remain developer tests rather than a phone/ship-path dependency.

Universal probe workflow remains two categories only: screenshot-triggered **FULL** and armed **VIEWPORT**.

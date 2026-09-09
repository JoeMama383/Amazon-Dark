# AmazonDark v7.377 — BYG controls / sparse renderer recovery / switcher source ownership

Direct parent: **v7.376~warm-switcher-noninterference**.

This release stays narrow and preserves the accepted checkout, Cart, Search, Person, Alexa, TWB, launch-seal, and universal-probe behavior outside the four proven corrections below.

- **BYG quantity control now matches Cart exactly.** The expanded dense-grid stepper is scoped under `.checkout-byg-mobile-container .byg-dense-grid-atc-container`: `#303335` fill, `#747a7c` 1px border, transparent plumbing, and white trash/minus/plus sprites.
- **Checkout decrement sprite is white.** The existing checkout quantity rule now includes `a-icon-small-remove` and `a-icon-small-subtract`, matching the already-correct Cart implementation.
- **Sparse BYG hydration recovery recognizes the actual failure.** The v7.374 good capture has row-2/col-2 ASIN `B0096XWNNY` with its normal ATC and price/details tail. Both v7.376 captures have that same faceout position with only image+title. v7.375 incorrectly required `.a-price` before it would attempt recovery, so the bad Crayon card could never qualify. v7.377 recognizes exactly one image+title / no-price / no-ATC sparse card with otherwise healthy siblings and nudges Amazon's real horizontal renderer once. It does not create a button, reload, observe mutations, poll, schedule timers, or run an RAF loop.
- **Teal warm/app-switcher regression is attacked at the upstream source owner, not covered.** v7.376 correctly removed all app-side warm/switcher covers and splash visibility suppression, yet the teal snapshot remained. The remaining SpringBoard branch inherited from v7.337 still hooked `_loadLiveXIBViewForApplication:` and replaced every Amazon return despite that selector carrying no snapshot kind or launch-request provenance. v7.377 removes that generic placeholder hook completely. Saved `SceneContent` and live placeholder/XIB views are untouched; only provenance-bearing `XBApplicationSnapshot` launch resources remain eligible for dark artwork. The probe-proven v7.350 AXU/Tez cold-splash seal remains in the Amazon process.
- **Probe identity is corrected.** The v7.376 universal probe files were named v7.376 but their header/body still reported v7.375/v7.374. v7.377 reports one consistent identity.

No app-switcher cover, warm splash hide/show state machine, background lifecycle painter, new UIWindow, snapshot deletion, MutationObserver, recurring timer, polling loop, or fake ATC control is added.

---

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

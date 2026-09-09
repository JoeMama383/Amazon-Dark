# AmazonDark v7.375 audit

## Parent
- v7.374 source archive
- Parent `src/Tweak.xm` SHA-256: `9b320db93e2bdae3b416e8ca0958821bc54e1fcc6b6048caf2694db1b302c743`

## Confirmed source bug folded in
`ADTWBJS` uses `shade = 0.10 + 0.48*t` for black overlay opacity and `factor = 1.0 - shade` for retained brightness. Three video-overlay alpha slots were incorrectly passed `factor`; v7.375 passes `shade`. `ADStandalonePaintJS7104`'s 12 format arguments were mapped position-by-position and are already correct: brightness slots use `factor`, the two black-overlay alpha slots use `shade`.

## Checkout
The v7.374 title/layout owner was too late for the titleless incoming modal and mutated nav paint during UIKit's active transition. v7.375 moves ownership to `AMSModalLayoutFullScreenViewController` lifecycle before composition, removes checkout layout-time reassertion, owns standard/scroll-edge/compact appearances, and forces exact checkout bar-item/back tint white.

The separate exact tan transition backing plane is matched by color + active checkout + full-width/plain-UIView structure. Zero model height is explicitly allowed because the probe shows Core Animation can already be presenting that layer onscreen.

## Duplicate presentation
No time-based debounce is added. The primary fix removes v7.374's transition-time layout mutation. A structural guard rejects only a same-presenter checkout request while the prior checkout modal is still live and not dismissing, so later legitimate checkout entry remains possible.

## Warm snapshot
The live hierarchy is black while the task-switcher/warm-entry capture is teal. v7.375 treats that as snapshot lifecycle leakage and uses a black, noninteractive, per-primary-window cover only from background through `DidBecomeActive`.

## BYG hydration
The missing `+` state is an absent Amazon ATC subtree. v7.375 never fabricates it and never reloads. One completed-card / one-missing-card signature can run one synchronous renderer nudge at load/pageshow, then marks the document so it cannot repeat.

## Performance contract
No production MutationObserver, interval, timeout, RAF loop, Web scroll listener, recurring hierarchy scanner, or polling loop is introduced by this release. Checkout ownership is lifecycle/setter driven; tan discovery has one bounded 128-node pass only when a checkout presentation is initiated.

## CI
`scripts/validate.sh` is called by GitHub Actions and `COMMANDS.md` before package/push. On-device it always runs Logos lint and gracefully skips the Python suite when `python3` is not installed. CI explicitly installs Python and invokes `AD_STRICT_VALIDATE=1`, making all 28 Python regressions mandatory before packaging. The Playwright `.cjs` render fixtures remain optional developer tests because they require the Playwright package/browser runtime.

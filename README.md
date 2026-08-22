# AmazonDark v6.0.209~experimental — Dark Reader mutation reconciliation off the input-critical path

- Exact functional/theming baseline: v6.0.185~probe.
- Keeps every v185 AmazonDark UI/theming/TWB/native/SpringBoard rule intact.
- Dark Reader itself is retained; no generated CSS is frozen and no theming subsystem is removed.
- Patches Dark Reader's high-frequency DOM-tree and inline-style MutationObserver reconciliation so it coalesces during Amazon hydration, waits for a 180 ms quiet window, then runs through requestIdleCallback.
- Continuous Home/PDP/Search DOM churn therefore keeps postponing Dark Reader reconciliation until the browser has idle time instead of competing with taps, swipes and scrolling.
- Initial Dark Reader enable/render remains synchronous and unchanged; only post-initial mutation reconciliation is deferred.
- Pending observer work is cancelled when Dark Reader disconnects/tears down, so no stale delayed reconciliation survives navigation.

# AmazonDark v6.0.185~probe — Buy Again nav re-entry border persistence

## v6.0.185 correction

- Keeps the v6.0.184 Interests caught-up gradient fix unchanged.
- Keeps the working v6.0.180 Buy Again TWB correction unchanged.
- Keeps the v6.0.183 whole-carousel gray border ownership and v6.0.184 detached-outline reattachment.
- Fixes the remaining bottom-nav re-entry case: v6.0.184 cleared Buy Again ownership when the Person React tree temporarily moved off-window. Because AmazonDark had already suppressed the original 51x51 white raster plate, returning to Person could leave the cards borderless.
- A claimed Buy Again card now preserves its association while temporarily detached.
- CALayer setContents suppression is active only while the claimed card is mounted and still resolves inside Buy Again; detached/recycled hosts may receive Amazon content normally.
- The existing current-controller viewDidAppear sweep now reasserts only already-owned or exact 51x51-style Buy Again card candidates, so a Person tree that remained mounted but had its sublayers rebuilt also recovers on tab return.
- No new observer, scroll listener, interval, RAF loop, nav-bar hook, or recurring recovery lane.
- Existing `AmazonDark-buyagain-probe-6180.txt` remains available; CARD records now include `window=` and `hidden=` alongside `marked`, `outline`, and `attached`.

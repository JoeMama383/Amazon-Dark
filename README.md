# AmazonDark v6.0.211~experimental — nested Home first-paint + one-frame DR inline catch-up

## v6.0.211 experiment

- Keeps the v6.0.209/210 delayed heavy Dark Reader tree-reconciliation path for input responsiveness.
- Fixes the remaining visible Home white-card flash by prepainting nested structural block surfaces inside proven Amazon product-card families, not only the outer shell.
- Leaves product/media, glyph/badge/deal/button/swatch/creative/poster leaves out of that prepaint.
- Shortens Dark Reader inline-style coalescing from 36 ms to 8 ms (roughly one 120 Hz frame) without restoring synchronous mutation processing.
- Everything else remains the v6.0.185 functional baseline.


- Exact functional baseline remains v6.0.185; v6.0.209 Dark Reader subtree scheduling is retained.
- Fixes the visible v6.0.209 tradeoff where aggressive Home scrolling could show stock-white product-card shells until Dark Reader's 180 ms quiet/idle reconciliation finally ran.
- Adds a documentStart-only structural prepaint for proven Home product-card shell families (a-cardui / NPACK / GWM / PUIS / cXVhZ containers). It changes only the shell background to #181a1b; product images, badges, controls and creative artwork are not selected.
- Keeps expensive Dark Reader childList/subtree reconciliation behind the 180 ms quiet + idle gate for input responsiveness.
- Separates Dark Reader's inline-style mutation lane: it now coalesces for 36 ms from the first mutation without repeatedly resetting the timer, so newly inserted card/background inline styles are corrected quickly instead of waiting until scrolling stops.
- No new MutationObserver, scroll listener, RAF loop, interval, document scan or native hierarchy traversal.

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

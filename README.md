# v6.0.205 — v6.0.185 input-latency correction

Built directly from the v6.0.185~probe baseline. Fixes a stale `_adTameFast362` lifecycle check that caused the complete TWB payload to be re-evaluated on every appearance/reapply burst, multiplying IMG/VIDEO event listeners in the live document. Removes multi-second unconditional web symbol/checkbox rescan bursts, stops carousel-dot changes from waking the whole-document checkbox scanner, removes Search-suggestion full-root fallback escalation, moves fallback media/contrast recovery off the immediate input path, and keeps AmazonDark auxiliary repair observers out of the exact PDP photo/video media subtree. Dark Reader, v6.0.185 visual rules, Buy Again/Interests fixes, native theming, JIT/120Hz, and existing first-paint CSS remain the baseline.

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

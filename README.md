# AmazonDark v6.0.187~probe — full-screen Product images TWB

## v6.0.187 correction
- Keeps every confirmed v6.0.186 behavior, including Buy Again border persistence, Interests gradient removal, Cart foreground recovery, and screenshot Share-preview TWB.
- Fixes the native full-screen `Product images` viewer so its large selected product image is forced through the existing TWB overlay owner instead of depending on whole-image average lightness.
- The exact viewer title `Product images` plus large-image geometry is required; thumbnail rail and navigation chrome are not promoted.
- Reuses assignment/didMoveToWindow ownership and adds only a one-shot semantic recovery when the exact title hydrates. No new observer, scroll callback, interval, RAF loop, or recurring scan.
- The retained 6180 probe now emits `GALLERY6187` records if a gallery image still misses.

## Retained v6.0.186 lineage
## v6.0.186 correction

- Built directly from the v6.0.185~probe source; the working Buy Again nav re-entry border fix and Interests gradient fix are retained unchanged.
- Targets Amazon's native/RN post-screenshot panel headed **"Share this product with friends"**.
- The large share-preview product image was outside the existing <=240 pt semantic TWB lane and can also carry Share-related accessibility ownership, so the normal generic lane can leave its baked white product-photo floor untouched.
- Adds one exact semantic owner for only a large preview image inside that panel: 220..520 pt wide, 110..430 pt high, minimum 32,000 pt², aspect ratio 0.85..3.8.
- Matching preview media is promoted into the existing native TWB overlay owner. The existing strength setting and overlay implementation are reused; no new filter math or image mutation is introduced.
- Messenger/Snapchat/Telegram/Reddit/X/Messages/Email/Copy/More icons are too small for the geometry gate and remain untouched.
- Reuses the existing RCTParagraphComponentView / RCTTextView / UILabel text lifecycle. When the exact heading hydrates, one main-queue bounded local pass re-submits only large UIImageView candidates in that panel, covering setter-before-image/parent timing.
- No new notification observer, scroll listener, interval, RAF loop, recurring scan, or window-wide TWB pass.
- The existing `AmazonDark-buyagain-probe-6180.txt` relay is retained and now also logs `SHARESHOT` records plus `shareImages=` in the summary when this panel is visible during a background capture.


## Previous v6.0.185 notes

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

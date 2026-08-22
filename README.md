# AmazonDark v6.0.188~probe — exhaustive screenshot Share renderer capture

## Probe-only change

- Built directly from v6.0.186~probe. No new Share/TWB production fix is added in this version.
- Retains v6.0.186 behavior exactly while expanding the existing background-triggered diagnostic so missed screenshot-share photos are logged even when they fail the v6.0.186 selector/gate.
- When **Share this product with friends** is visible and Amazon is backgrounded, the existing `AmazonDark-buyagain-probe-6180.txt` output now adds a `SHAREPANEL6187` section.
- The probe records every visible `UIImageView` under the Share sheet, not only views that already qualify as v6.0.186 Share previews.
- For each image it records class, screen/bounds geometry, source pixel dimensions, content mode, current TWB overlay, cached TWB decision/context/lightness, each v6.0.186 Share gate (`geom6186`, `near6186`, `product6186`), template/UI-chain/WebKit/tab exclusions, backing-layer contents/backgrounds, accessibility metadata, and a bounded ancestor chain.
- It also records non-UIImageView CGImage-backed raster views and CGImage/gradient sublayers so a flattened/Fabric painter cannot disappear from the diagnostic just because it is not a normal UIImageView.
- Diagnostic traversal runs only on `UIApplicationWillResignActiveNotification`; no new timer, scroll callback, RAF loop, DOM observer, or paint mutation is introduced.

## Previous v6.0.186 notes

# AmazonDark v6.0.186~probe — screenshot Share preview TWB

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

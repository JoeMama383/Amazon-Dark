# AmazonDark v6.0.193~probe — screenshot Share preview exact TWB owner

## Base / confirmed state

- Exact source base: v6.0.191~probe.
- The v6.0.191 full-screen **Product images** fix is retained unchanged; the user confirmed the gallery photos are now fixed.
- The remaining issue is the screenshot-triggered **Share this product with friends** panel, where some product photos still escape TWB.

## What v6.0.191 proved

- Background-time native lookup repeatedly returns `SHAREPANEL6187 root=none phraseVisible=0`.
- The only plausible surviving renderer is `WKCompositingView`; no matching native UIImageView/raster is visible by the time Amazon backgrounds.
- The existing UILabel / RCTParagraph render-time text hooks also never emit `SHARETEXT6189`, so the Share header is not travelling through those native text setters.
- Therefore the next diagnostic target is the mounted WKWebView DOM/compositor while the Share surface is actually on screen.

## v6.0.193 exact Share-preview correction

Probe 6192 identified the failing screenshot Share preview exactly: it is a WebKit `DIV#ssf-preview-container.ssf-preview-container` whose product creative is a CSS `background-image`, inside `.a-sheet-web[role=dialog]`. It is not a native `UIImageView` and not an HTML `IMG`.

v6.0.193 adds one declarative TWB rule for that exact preview plane using the existing user-configured TWB brightness filter. Because the stylesheet already exists before the sheet is created, late Share-sheet hydration is covered without a new observer, timer, scroll callback, or hierarchy scan. Full-screen Product images behavior from v6.0.191 remains unchanged.

The Reviews Share glyph and the blank overlapping comparison circles are intentionally not changed in this build because probe 6192 did not capture their exact painter/DOM leaves.

- Registers one `UIApplicationUserDidTakeScreenshotNotification` observer.
- At +250 ms, +800 ms and +1600 ms after the screenshot, performs one-shot diagnostic captures only.
- Each stage:
  - runs the existing native Share hierarchy dump;
  - discovers mounted WKWebViews with one bounded view traversal;
  - evaluates read-only JavaScript in each mounted WKWebView;
  - records whether the page contains `Share this product with friends`;
  - records phrase/root candidates, visible image/video/canvas/background-image media, large overlay/fixed-position elements, hit-test ancestor chains, iframe metadata, URL/title/readyState, and viewport geometry.
- Output records use `SHARESCREENSHOT6192`, `SHAREWEBSTART6192`, and `SHAREWEB6192` in the existing `AmazonDark-buyagain-probe-6180.txt` file.
- Each completed web result notifies the existing SpringBoard relay, so `/var/mobile/AmazonDark-buyagain-probe-6180.txt` is refreshed without relying on NewTerm access to the AppGroup path.

## Production behavior

- No Share TWB production rule is changed in this build.
- No Product images behavior is changed from the confirmed-good v6.0.191 implementation.
- No DOM node, style, filter, image cache, Dark Reader state, WebView navigation state, or native view/layer is mutated by the new probe.

## Runtime discipline

- No new MutationObserver.
- No scroll listener.
- No setInterval.
- No requestAnimationFrame loop.
- No recurring scanner.
- The +3 `dispatch_after` sites are diagnostic one-shots triggered only by an actual system screenshot notification.

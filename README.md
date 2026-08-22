# AmazonDark v6.0.191~probe — persistent Product images gallery TWB + Share probe

## v6.0.191 correction

- Exact base: v6.0.190~probe.
- v6.0.190 proved the dedicated full-screen **Product images** TWB owner works: the sampled 430x410.7 / 1290x1232 main image had `overlay=1`.
- User still reports a minority of swiped gallery images escape TWB.
- Root cause addressed here: v6.0.190 tied ownership to the first large ancestor reached from the `Product images` title. Amazon can recycle/swipe image pages in sibling hosts outside that first root.
- v6.0.191 keeps an ARC-weak reference to the exact live `Product images` title and its UIWindow. While that title remains mounted, large UIImageViews in that same window are direct gallery owners regardless of which recycled/sibling page host they occupy.
- The geometry remains gallery-specific and excludes the bottom thumbnail strip and header/nav artwork.
- The title event now performs one bounded window catch-up instead of a root-only catch-up. New/recycled images remain event-driven through the existing UIImageView / RCTUIImageViewAnimated hooks.
- The weak title/window state automatically becomes inactive when the gallery title leaves the window; there is no persistent global gallery mode.

## Diagnostic additions

- Backgrounding while **Product images** is visible now writes `GALLERYPANEL6191`, `GALLERYIMG6191`, `GALLERYRASTER6191`, and `GALLERYSUMMARY6191` to the existing `AmazonDark-buyagain-probe-6180.txt` file.
- This tells us whether any remaining untamed page is a normal UIImageView (`overlay=0`) or a flattened CGImage-backed UIView/CALayer.
- The screenshot-Share 6189 diagnostics remain intact.
- The `/var/mobile/AmazonDark-buyagain-probe-6180.txt` SpringBoard mirror from v6.0.190 remains intact, avoiding the NewTerm/AppGroup permission problem.

## Runtime discipline

- No new MutationObserver.
- No scroll listener.
- No setInterval.
- No requestAnimationFrame loop.
- No recurring window scan.
- One bounded window traversal occurs only when the exact `Product images` title hydrates.
- Gallery diagnostics run only on the existing app-background probe capture.

# v7.361 evidence and scope

Baseline: v7.360, Git commit `aab59b0370eeec3ea4e4cff7741e200950f85db1`.
The recovered `AmazonDark-v7.360-search-tiles-cart-coupon-fix-source.zip` has SHA-256
`a599f4602ff986fc1d539cb2a0b77ae8ab6ca08d833ef1522c915932579129a5`.
Every file it contains matches the same Git tree. No earlier UI baseline was substituted.

All six supplied probe headers report `v7.360-search-tiles-cart-coupon-fix` despite their historical v7.309 filenames. Archive(3) duplicates Archive(2); the reattached r6 and Cart probes duplicate their earlier copies. Screenshots IMG_6441 through IMG_6449 were compared by issue, including the three distinct heart states.

| Issue | Captured owner / evidence | Change |
| --- | --- | --- |
| Everyday ad | Product r1, 140945, n110–149: `featured-brands-search-top-mobile-cards`, white AsinContainer/image floors, unfiltered product image, separate Prime/star leaves | OLED structural backgrounds; white neutral copy; configured TWB on exact product and BrandLogoContainer image leaves. Preserve colored copy and Prime/stars. |
| White two-cards button | r1 n227 and r3 n211: standalone `more-like-this-container .mlt-icon-container`, outside spotlight | Theme the button family in the existing floor and TWB styles, including late-inserted controls. Preserve transparent menu variant. |
| Duplicate placeholder heart | r4 n438–439: a white placeholder with a background image plus an image child | Remove only the duplicate placeholder background when the child exists; retain the child asset. |
| Empty hydrated heart | r5 n436–438: gray parent, 16px child with no background image/mask; v7.360 explicitly erased the parent's background image | Remove the destructive parent background shorthand/image reset. Preserve Amazon artwork and invert the small monochrome control once; complementary shell/edge colors render as #303335/#747a7c. Legacy child-art and parent-art fixtures both retain visible glyphs. |
| Invisible Select | r4 n481 / r5 n484: existing CSS mask, transparent background | Supply opaque light mask ink; leave mask and geometry intact. |
| Pink Cart coupon | Cart step0 n93–110: Apex tile under `data-csa-c-painter=cart-coupon`, rgb(255,227,227), without a legacy a-button | Target Apex tile directly with #008000 and white text/price; keep checkbox and state behavior. |
| Untamed Alexa carousel | r6 n175–229: Nice category carousel, five `nice-cat-card_image` leaves, filter none; separate 20px Alexa icon | Add the exact carousel image family to the existing strength-controlled TWB selector. |

The empty-heart probe records computed paint after the old rule erased its background, so it cannot reveal the original parent asset bytes. Parent-art ownership is an inference from that evidence, not a captured untweaked stylesheet. This change preserves whatever artwork Amazon supplies; it does not synthesize or download a replacement heart. Live-device confirmation remains necessary.

## Validation

- Rendered the actual ADFloorJS/ADTWBJS payloads in Chromium against fixtures built from the captured owners. The v7.360 negative controls reproduce white card/MLT surfaces, untamed category images, transparent Select and the blank parent-art heart.
- Checked synchronous first-paint styles, later insertion, placeholder replacement, late stylesheets, two TWB strengths, actual gray/white pixels, Prime/star/colored-copy preservation, saved-heart artwork, checkbox operation and unchanged control geometry.
- Existing Cart renderer regression checks pass: buying-options button, exact 13px shimmer strip and authored loader/image-shimmer backgrounds. Corrected invalid unquoted SVG test URLs in that inherited fixture; no production Cart loader change was needed.
- Python regression scripts pass, including cold-launch policy, startup safety, preserved native splash hashes, probe embedding, prior UI contracts and probe export/upgrade receipts.
- Rootless Theos package build uses iOS 16.5 SDK and the C++98 compatibility dialect. Local Linux arm64e compiler ABI warnings apply; the user's unchanged macOS GitHub Actions workflow remains the installation build path. No device run or remote Actions success is claimed.

## Preserved boundaries

Outside ADFloorJS/ADTWBJS and the runtime version literal, `src/Tweak.xm` is byte-identical to v7.360. `src/AmazonDarkSB.xm`, standalone paint payload, native splash behavior, warm/app-switcher code, skeleton JavaScript, Makefile and Actions workflow are unchanged. No new native hook, timer, observer, recurring scan or readiness machinery.

Probe-native changes are filename/version substitutions only. The shell helper's current version/receipt validation is updated consistently to v7.361 and accepts the previous v7.360 receipt when container metadata is unavailable. Screenshot-triggered Product Search/Cart probes retain their existing capture behavior and filenames.

The full source handoff includes the updated source, existing workflows/probes, regression tests, commands and baseline metadata. It excludes local build products and raw user screenshots/probes.

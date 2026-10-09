# AmazonDark v7.597 changes

Base: the delivered v7.596 source ZIP (SHA-256 `255ee2546b3cb52588330f7f6711174f98e96ccbb1e8d7f6cbf36bb6e2be1ea0`).

## Evidence and cause

Reviewed all three supplied captures in Archive(8).zip and IMG_7802, IMG_7804 and IMG_7806. The Amazon Live FULL r3 capture completed. Checkout VIEWPORT r1/r2 report partial status; their captured visible owners were used without treating them as complete inventories. No probe-state change is needed to theme those captured owners.

The missed checkout music cards use the `_YXN2L_baseTile_` / V2 family, rather than the previously covered V3 family. The sponsored continuation rail uses `sp-dynamic-image`, rather than the previously covered p13n images. The rectangular gray Add to cart backing is a separate parent floor. The standalone Live destination has its own page root and hashed component families.

## Changes

- Checkout music cards: OLED inner floors, white product titles, gray secondary copy, configured image dimming. Preserve the orange featured border/backing/strip and rating stars.
- Checkout continuation rail: dim the sponsored product images, OLED their container floors, and clear the gray Add to cart parent rectangles.
- Amazon Live destination: OLED captured header/feed/card/image/skeleton floors; white neutral headings/prices; gray secondary copy; gray category pills; OLED Add to cart controls with gray borders and white text; gray dividers and player menu/control floors.
- Live artwork: dim product images, thumbnails, avatars, video and clear posters at the existing configured strength. Keep the stock blurred poster treatment. Apply no dimming filter to text/control ancestors. Preserve orange selection rings, Live badges, red deal surfaces, stars and colored links.
- Search: gray shell, gray placeholder and matching gray magnifying glass; typed text and its adjacent glyph become white. The exact native CXI top-bar back/search buttons also become white; branded Home and other buttons are excluded.
- Live wordmark: a scoped SVG filter lifts the dark navy lettering to white while preserving orange and source alpha. The brand logo is excluded from photo dimming.

## Runtime and scope

One idempotent stylesheet plus one idempotent SVG filter definition, delivered through the existing cached all-frame theme assembly. No new timer, event listener, observer or DOM walker. Native glyph handling is restricted to two identifiers on the exact CXI class, checks at most three ancestors, and avoids repeating unchanged image/tint writes.

The v7.596 performance recorder and runtime optimizations remain. Probe/export/package identities advance to v7.597; no measured speedup or device-rendered result is claimed.

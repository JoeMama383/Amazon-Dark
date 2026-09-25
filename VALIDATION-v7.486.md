# AmazonDark v7.486 validation

Direct parent: **v7.485~ci-validator-identity-repair**.

## Device evidence

Supplied capture: `AmazonDark-v7.485-ui-viewport-probe-20260925-054248-355-r1.tar`.

The capture proves the remaining visible book-menu fade is not `.a-divider.a-divider-section`. It is the `::after` pseudo of `li.a-carousel-card.davinci-triad-background-color.putb-card` beneath `#putb_immersive_view_carousel.image-block-putb-grey-overlay-enabled`. The probe reports `after.bgImage=gradient`, `after.width=360px`, and `after.height=48px`; the native WebKit compositor independently exposes a positioned `<pseudo>` layer at the lower card edge with a 360 × 48 frame.

Historical comparison against the supplied v7.480 VIEWPORT r1 and r2 captures reports the same exact `li.putb-card::after` gradient family at 362 × 48 px on both Book details / What's it about immersive views. This makes the owner shared across both book menus rather than a one-off card.

## v7.486 production change

The exact scoped rule now suppresses only:

`#putb_immersive_view_carousel.image-block-putb-grey-overlay-enabled li.putb-card::after`

under `.a-popover.putb-immersive-view-gallery`.

It clears content/display, width/height, background/background-image, shadow, and opacity. The underlying card, its gray border, and the authored blue selected pagination dot are not removed or recolored.

## Validation

- `tests/test_v7486_putb_overlay_fade.py`: PASS.
- `src/ADNewMenus7482.js.inc`: decoded JavaScript parses with `node --check`.
- Same include compiles as adjacent literals under C99 and GNU++98.
- `scripts/ui-probe.sh`: shell syntax PASS.
- `scripts/skeleton-probe.sh`: shell syntax PASS.
- `scripts/lint-logos.sh`: PASS.
- Complete normalized Python regression corpus using the exact current `scripts/validate.sh` identity-normalization algorithm: **163/163 PASS** in four bounded batches (45 + 45 + 45 + 28), zero failures.
- `src/Tweak.xm`: **854,050 bytes**, below the frozen 856,000-byte gate.
- New production recurring mechanisms: none (`MutationObserver`, polling timers, RAF loops, web scroll listeners remain absent from the v7.486 payload).

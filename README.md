# AmazonDark v7.486 — PUTB book overlay fade removal

Direct parent: **v7.485~ci-validator-identity-repair**.

v7.486 keeps the v7.485 CI/validator repair and all v7.483/v7.484 UI work, and corrects the remaining white fade in the two immersive PDP book menus.

## Probe-backed root cause

The supplied v7.485 VIEWPORT r1 capture identifies the visible fade as the `::after` pseudo-element of the exact immersive carousel card:

- owner: `li.a-carousel-card.davinci-triad-background-color.putb-card`
- parent carousel: `#putb_immersive_view_carousel.image-block-putb-grey-overlay-enabled`
- pseudo: `::after`
- computed pseudo background: gradient
- computed pseudo size: `360 × 48` px
- WebKit compositing layer: positioned `<pseudo>` at the lower edge of the card

The earlier v7.480 Book details and What's it about VIEWPORT r1/r2 captures show the same owner and the same 48 px pseudo overlay (362 × 48 px in those captures). The previous v7.483-v7.485 rule targeted an AUI divider fade instead, so it could not remove this overlay.

v7.486 removes only that exact `image-block-putb-grey-overlay-enabled` PUTB card `::after` pseudo. The card itself, gray border, text treatment, image taming, and authored blue pagination selection remain intact.

No MutationObserver, polling, requestAnimationFrame loop, scroll listener, or recurring production hierarchy scan was added.

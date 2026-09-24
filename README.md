# AmazonDark v7.482 — PDP immersive, review, and profile-picker completion

v7.482 preserves the v7.481 Returns completion and adds three probe-backed menu families from the supplied v7.480 VIEWPORT captures.

## PUTB immersive Book details / What's it about

VIEWPORT r1/r2 identifies the exact secondary-view owner as `.a-popover.putb-immersive-view-gallery`, with the white wrapper/header, `li.putb-card` white card, `putb-card-immersive-view`, raster icon bullets, and `#putb-pagination-dots`. v7.482 makes the shell and cards OLED, neutral copy white/light-gray, dividers/borders gray, safely inverts the monochrome detail glyph rasters, and preserves the authored blue selected pagination dot.

## In-context review form

VIEWPORT r3 identifies `#react-app.ryp__mobile`, `#in-context-ryp-form`, the review textarea/title input, white media-upload tile, yellow primary submit control, product thumbnail, orange star family, and blue Clear link. v7.482 applies OLED floors, white/light-gray neutral text, dark controls with gray borders, a dark upload tile with visible camera glyph, and the standard OLED primary button. The orange star graphics and blue Clear link are explicitly preserved; the product thumbnail receives the existing image-taming treatment.

## Switch Accounts bottom sheet

VIEWPORT r4 identifies the visible React sheet as `RCTView#sheet-view` / `#sheet-inset-view`, uniquely gated by `profile-picker-close-bottomsheet-button`. v7.482 extends the existing exact sheet owner rather than introducing a generic React traversal. Neutral white sheet/row planes become OLED, neutral dark header/close/account text becomes light, the 1 px separator becomes the standard gray divider, while the authored blue selected-account outline and teal account actions remain untouched.

No MutationObserver, polling, requestAnimationFrame loop, scroll listener, or recurring production hierarchy walk is added by these fixes.

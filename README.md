# AmazonDark v7.371 — residual checkout / BYG probe fixes

Direct production base: **v7.370~checkout-script-reinstall-theme**.
Parent `src/Tweak.xm` SHA-256: `c6a6dd0dcbead983bfe4d785eff407f7dfd94768a0a8139b9506c41d3517607b`.

v7.371 changes only the residual issues proven by the v7.370 FULL probes:

- BYG product images: keeps the dense-grid ATC overlay plumbing transparent so the 32px
  add-button row no longer paints across and visually cuts product photos.
- Place Your Order header: the native bar itself was already OLED black, while r3 proved its
  direct image-backed `UIImageView` remained visible. The exact `Place Your Order` nav now
  suppresses that leaf from `_UIBarBackground` and reasserts it at the image lifecycle.
  `DONE`/title remain light; the exact nav button title/tint state is also forced light because r3 showed the button state itself remained dark.
- Payment summary: exact `#payment-option-text-default` and `#payment-option-text-1` are light.
- Manufacturer-container dropdown: exact outer/inner white owners become OLED black, with
  a single `#747a7c` outer border and light text.
- Subscribe & Save / gift-options checkbox press state: exact `.a-touch-press` row remains
  OLED black with light copy while the authored blue checkbox-ring sprite is untouched.

No change is made to the shared `ADFloorJS`, `ADTWBJS`, or `ADCoreWebJS7271` behavior outside
the already-isolated checkout script. No MutationObserver, interval, RAF loop, web scroll
listener, recurring hierarchy scan, or renderer polling is added.

# AmazonDark v7.587 diff

Base: `v7.586~medical-health-auth-followup`
Target: `v7.587~medical-bottomsheet-auth-logo-followup`

## Probe/screenshot-driven fixes

- Verification/auth menu:
  - the white Amazon logo strip above the verification card is now OLED black;
  - Amazon logo assets in that strip are inverted so the mark is no longer dark on white.
- One Medical bottom-sheet menu with dividers (`links-bottomsheet`):
  - exact bottom-sheet floors are now OLED black;
  - the modal shell and modal content surfaces are forced OLED black;
  - text inside the sheet remains white;
  - the Amazon One Medical logo owner (`mobile-kyanite-logo`) is inverted per request;
  - gray divider ownership is retained.
- ZIP-code bottom sheet (`glowModal`):
  - exact bottom-sheet floor owners are now OLED black.

## Retained / synchronized

- v7.586 Health AI, Warbler, verification/help-copy, and One Medical continue-button fixes remain in place.
- FULL / VIEWPORT / TRANSITION probe identity is bumped to v7.587.
- No recurring DOM walker, MutationObserver, interval, timeout, RAF loop, or scroll scan was introduced.

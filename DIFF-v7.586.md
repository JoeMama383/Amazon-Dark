# AmazonDark v7.586 diff

Base: `v7.585~medical-auth-probe-followup`
Target: `v7.586~medical-health-auth-followup`

## Probe/screenshot-driven fixes

- Health AI storefront / Ask Health AI:
  - neutral dark hourglass and related neutral SVG icon paint -> white;
  - Ask Health AI send/up-arrow control now matches its gray host surface with no separately drawn border;
  - broad Health AI yellow/primary/continue pills -> OLED black with gray border and white text;
  - visible Health AI imagery/SVG owners are forced visible; neutral black SVG paint is whitened.
- Health AI recommendations / quick-action rail:
  - right-edge fade / mask overlays inside Warbler quick-action or carousel surfaces are neutralized to transparent;
  - quick-action/rail masks are removed so no white translucent edge remains.
- Verification / auth flow:
  - footer/gradient family and offset gray helper rows -> OLED black with standardized gray borders;
  - neutral help / expander copy (including the text above “change your number”) -> white while authored links remain authored.
- One Medical account-confirm / contact-confirm menu:
  - shared white/off-white container family -> OLED black with standardized gray borders;
  - yellow continue/primary controls -> OLED black, gray border, white text.

## Retained / synchronized

- Existing v7.585 medical picker / Warbler quick-action / auth fixes remain in place.
- FULL / VIEWPORT / TRANSITION probe identity is bumped to v7.586 with current-session TAR behavior retained.
- No new recurring DOM walker, MutationObserver, interval, timeout, RAF loop, scroll listener, or geometry scan was introduced.

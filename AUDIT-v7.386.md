# AmazonDark v7.386 audit — sponsored shell ownership

## Probe-backed diagnosis
The v7.385 FULL probe captured the blank Home cards after the sponsored blocker had run.

1. Top dashboard blank:
   - outer owner: `li.gwm-tile`, rect `161 x 214.7`, still `display:block`;
   - immediate widget: `#md-grid-1`, `data-csa-c-painter="gwm-asin-tile"`, class begins `mobile-gateway-atf_Spons…`, already `display:none` and `0 x 0`;
   - therefore v7.385 removed the sponsored widget but not its layout-owning `li`.

2. Recommended-deals mosaic blank:
   - outer owner: `_hp-mosaic-container_*widgetContainer*` `li`, rect `326.8 x 467.8`, still `display:list-item`;
   - direct widget: `data-csa-c-painter="npack-asin-card-cards"`, already `display:none` and `0 x 0`;
   - its card header directly owns `_widget-sponsored-badge-container_`, proving the whole card is sponsored rather than merely containing a sponsored product tile.

## v7.386 correction
Two narrow outer-shell selectors were added to `ADSponsored.m`:

- dashboard shell collapses only when its direct `gwm-asin-tile` widget carries Amazon's `mobile-gateway-atf_Spons` class family;
- mosaic shell collapses only when its direct `npack-asin-card-cards` widget has a sponsored badge in that card's own header.

Both selectors use one non-nested `:has()` and the existing zero-size collapse declaration. No generic "any sponsored descendant => remove carousel card" rule was restored, avoiding the v7.381 regression that deleted legitimate subsequent cards.

## Preserved behavior
- v7.381 OLED Home ad-loading floor remains unchanged for ads-enabled mode.
- Existing v7.385 sponsored selector families remain unchanged.
- Price history, checkout, BYG, Cart, Search, Person, Alexa, TWB and cold-launch theming are untouched.
- No MutationObserver, polling, recurring timer, RAF loop, scroll listener or runtime DOM scan was added.
- No app-switcher cover or warm-splash suppression was added.

## Release/diagnostic maintenance
Release/probe identity is v7.386. `skeleton-probe.sh` also accepts the current v7.386 receipt and carries v7.385/v7.384/v7.383 receipts across an upgrade when plist discovery is unavailable. This is diagnostic helper maintenance only.

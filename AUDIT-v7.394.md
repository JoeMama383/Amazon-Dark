# AmazonDark v7.394 audit — checkout address + pickup + help UI

## Baseline

- Direct parent: `7.393~payment-help-ui-fix`.
- Runtime identity: `v7.394-checkout-address-pickup-help-fix`.
- This release retains v7.393 Payment Method + Privacy/Returns/Consumer Tax/help-feedback work and all earlier checkout, Subscribe & Save, app-switcher, gift-options, address-selection and recurrence-selector theming.
- Evidence for the new work came from four v7.392 universal FULL captures at 17:20, 17:25, 17:28 and 17:38.

## 1. Add an address

Probe-backed owners:

- `#address-ui-widgets-enterAddressFormContainer`
- `#address-ui-widgets-countryCode`
- `#address-ui-widgets-DetectLocationButton`
- `#address-ui-widgets-enterAddressStateOrRegion`
- `#address-ui-widgets-delivery-instructions-mobile-touch-link`

Changes:

- White country/state/location/delivery-instructions controls -> standard `#303335` control fill.
- Standard border -> `#747a7c`.
- Neutral control text -> `#e8e6e3`.
- Country/state dropdown chevrons, clear-X raster and delivery-instructions touch-link glyph -> light.
- Existing dark text fields are not broadened or repainted unnecessarily.
- Checkbox/radio artwork and authored/dynamic colors remain untouched.

## 2. Select a pickup location

Exact renderer root: `#bolt-widget-amazon_us_checkout_generic_mobile`.

Changes:

- Country dropdown -> dark control treatment.
- Sort strip -> OLED black.
- Recommended / Nearest / Fastest controls -> OLED black + `#747a7c` edge + light neutral copy.
- Selected sort keeps an explicit Amazon-blue selection cue without restoring its pale-blue floor.
- Handicap/lower-locker glyph and its divider are preserved.
- Pickup card panel and actual direct card owners (`#bolt-widget-card-panel > [id^='bolt-widget-card-']`) -> OLED black.
- Neutral card text -> light; secondary/tertiary gray and authored links remain authored.
- Existing selected-card orange accent is not overwritten.
- Pickup primary action button -> OLED black + standard gray border + white text.
- Only the Bing base road imagery canvas (`canvas#Microsoft.Maps.Imagery.LiteRoad`) is routed through the existing checkout TWB strength. Label/marker/accessibility layers are not statically filtered.

Audit correction during final review:

- An earlier draft targeted `[role='listitem']` beneath `#bolt-widget-card-panel`, but the FULL probe proves the actual pickup-card owners are direct `div#bolt-widget-card-*` children. v7.394 uses the proven ID family instead so the visible access-point cards are actually covered.

## 3. Checkout Delivery / Pickup toggle

Probe family: `.edg-delivery-type-toggle-button`.

Changes:

- Both button floors/interiors -> OLED black.
- Neutral copy -> light.
- Unselected edge -> `#747a7c`.
- Selected button's Amazon-authored blue outline/selection state is deliberately not overwritten.

## 4. Subscribe & Save Terms / help-search suggestion UI

Web owners:

- `.cs-help-v4 .cs-help-content #suggested-help-topics-wrapper`
- `.suggested-help-topics-title`
- `.suggested-help-topics-button`
- `.star-note-icon`

Changes:

- Suggested-topic sheet and rows -> OLED black.
- Neutral copy -> light.
- Row separator/border color -> standard gray.
- Star-note glyph -> visible light treatment.

Native keyboard / accessory evidence:

- The HTML help search becomes first responder through `WKContentView`, not a normal `UITextField` / `UITextView`.
- `WKContentView -becomeFirstResponder` therefore requests the same dark keyboard appearance already used by AmazonDark's native responders.
- The probe shows the large gray strip above the keyboard is an exact Web form accessory toolbar: a `UIToolbar` under `UIWebFormAccessory`, with a full-width image-backed `_UIBarBackground` child.
- v7.394 scopes ownership structurally to `UIWebFormAccessory`, paints the toolbar OLED black, hides only that full-width stock gray background raster, and forces Done/arrow controls to white.
- Navigation toolbars elsewhere are not broadened.

## Performance / architecture

The release adds no:

- `MutationObserver`
- polling loop
- recurring timer / interval
- RAF loop
- Web scroll listener
- recurring hierarchy scanner
- extra `WKUserScript`
- generic map/image filter
- generic app-switcher cover

New Web theming is declarative CSS inside the existing checkout program. Native keyboard work is event-driven on existing responder/mount/layout callbacks. Map taming reuses the existing user-controlled checkout TWB program.

## Validation

- `scripts/lint-logos.sh`: PASS.
- All 50 Python regression scripts other than the exhaustive handoff test: PASS when run individually with bounded timeouts.
- `tests/test_probe_handoff.py`: PASS as part of strict validation before the overall validation wrapper reached the environment timeout.
- New `tests/test_v7394_checkout_address_pickup_help_fix.py`: PASS after final card-owner correction.
- Reconstructed `ADCheckoutFloorJS7369`: Node syntax PASS.
- Reconstructed `ADCheckoutTWBJS7369` at TWB 45: Node syntax PASS.
- Strict validation progressed through the complete probe-handoff suite and all historical checks through the v7.377/v7.388 contract before the external command timeout; no test failure was observed.
- Full local Theos/iOS SDK package build is not claimed in this environment; phone/GitHub Actions remains authoritative.

## Device verification targets

After install, verify these four new areas independently:

1. Add an address controls and chevrons/clear glyphs.
2. Pickup map, sort controls, pickup-card text/floors, preserved selected accents and Pick up here button.
3. Checkout Delivery/Pickup toggle, especially selected blue state.
4. Subscribe & Save Terms search suggestions, OLED keyboard, black accessory strip and white Done/arrows.

If any visible painter remains, capture that exact state with the universal FULL probe rather than adding a route-specific probe.

# AmazonDark v7.395 audit — UI coverage re-audit

## Base

- Direct parent: `7.394~checkout-address-pickup-help-fix`.
- v7.394 visible-state theming remains intact.
- Re-audited the v7.389/v7.392 FULL probes against the actual v7.394 selectors rather than only the screenshots.

## Residual gaps found and fixed

### 1. Help search typed-query list
The 17:38 FULL probe contains two suggestion systems: the visible `#suggested-help-topics-wrapper` already handled in v7.394, and a separate pre-mounted `ul#help_srch_sggst` with a stock white floor. It is hidden until typed-query suggestions take over. v7.395 themes this exact list and its rows to OLED/light/gray without broadening help-page ownership.

### 2. Add-address location feedback/error state
The Add-address FULL probe also contains pre-mounted `#address-ui-widgets-address-form-location-autofill-feedback-message .a-changeover-inner` and `#address-ui-widgets-location-detection-error-touch-link` white surfaces. v7.395 darkens those exact owners so invoking `Use my location` cannot reveal a fresh white feedback/error panel. Links remain authored.

### 3. Pickup success/error alert state
The Bolt pickup FULL probe contains zero-rect pre-mounted `a-alert-success` and `a-alert-error` cards with white floors. v7.395 darkens those alert floors and neutral copy while deliberately preserving Amazon's green/red accent border colors.

## Rechecked requested visible surfaces

- Help & Contact topic cards/rows/chevrons: covered.
- Subscribe & Save loading overlay/spinner tile: covered.
- Lower-carbon sheet: covered.
- Gift Options cards/fields/button/borders: covered.
- Checkout Prime Business Card block + TWB image lane: covered.
- Select Payment Method cards/text/selected blue ring/switch state/art + purple heading outline removal: covered.
- Select delivery address cards/buttons/dividers/radio/link states: covered.
- SNS recurrence selector rows/text/gray dividers/selected blue cue: covered.
- Privacy Notice + feedback family: covered.
- Returns & Refunds cards/rows/chevrons/divider cleanup + feedback: covered.
- Consumer Use Tax table/text/borders + feedback: covered.
- Subscribe & Save Terms search suggestions + OLED keyboard/accessory: covered; typed-query alternate list now closed here.
- Checkout Delivery/Pickup toggle: covered, selected blue state preserved.
- Pickup location map/sort/card/action text and dynamic colors: covered; latent alerts now closed here.
- Add an address controls/glyphs: covered; location feedback/error state now closed here.

## Architecture

No MutationObserver, interval, RAF loop, Web scroll listener, polling loop, recurring hierarchy scan, new WKUserScript, generic app-switcher cover, or generic image-filter expansion was added. The three new fixes are declarative selectors inside the existing checkout/floor program.

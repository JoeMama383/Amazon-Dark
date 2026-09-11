# AmazonDark v7.399 — Add-address form completion

v7.399 is built directly on v7.398 and preserves the legal/help completion pass, payment controls, checkout/address transition seal, pickup UI, keyboard/accessory fixes, sponsored ownership, probes and performance architecture.

The supplied v7.398 universal FULL capture identifies the current screen as the checkout **Add an address** form (`#address-ui-widgets-enterAddressFormContainer`). Most of the menu was already correctly themed: OLED page/navigation floors, light headings/labels/field text, dark country/state and delivery-instructions controls, authored checkbox artwork, and the OLED Continue button.

Two paint-owner families remained stock white. All six visible `a-input-text-wrapper.addrui-form-text-input-container` shells (plus the pre-mounted hidden Urbanization field) were white even though their child inputs were already dark. The mounted AUI warning card and its inner container were also white.

v7.399 owns only those exact families. Address input shells now use the existing dark input floor (`#181a1b`) and standard `#747a7c` edge; child inputs become transparent so the field reads as one surface. `:focus-within` keeps an Amazon-blue focus cue. The warning shell becomes OLED black while its authored orange warning edge and already-light copy remain untouched. Clear/dropdown glyphs, checkbox art, links, location/error states, field geometry, and the bottom Continue control are unchanged.

No MutationObserver, interval, RAF loop, Web scroll listener, polling loop, recurring hierarchy scan, new WKUserScript, generic input recolor, or image filter is added.

See `AUDIT-v7.399.md` and `COMMANDS.md`.

# AmazonDark v7.400 — Delivery Instructions completion

v7.400 is built directly on v7.399 and preserves the completed Add-an-address form, legal/help coverage, payment controls, checkout/address transition seal, pickup UI, keyboard/accessory fixes, sponsored ownership, universal probes and performance architecture.

The supplied v7.399 FULL capture proves the reported **Delivery Instructions** menu is not part of `#address-ui-widgets-enterAddressFormContainer`, which is the family v7.399 completed. Amazon mounts this screen as a separate AUI secondary popover: `.a-popover.a-popover-secondary` containing `.ma-cdp-form`. Because the prior release was scoped to the Add-an-address form, its new rules never matched this menu.

The earlier v7.398 FULL r5/r6 captures also contained this `.ma-cdp-form` tree pre-mounted while hidden. v7.400 uses that evidence to theme the complete stable family before presentation rather than fixing only the currently visible rows.

The secondary popover shell, Back/header strip, accordion cards and contents become OLED black with standard `#747a7c` structure. Neutral headings and labels become light, secondary/tertiary helper copy becomes readable `#b1aaa0`, and authored links/semantic colors remain authored. Security-code, call-box and free-text wrappers use the existing `#181a1b` input floor with gray edges and a blue focus cue. Pre-mounted property-type/dropdown/toggle controls use the standard dark-gray control treatment while selected Amazon-blue state is preserved. The yellow Save/Edit action family is converted to AmazonDark's black oval-control treatment with gray border and light text. Validation-card floors are darkened without replacing Amazon's red/orange semantic edges, and radio/checkbox sprites remain untouched.

No MutationObserver, interval, RAF loop, Web scroll listener, polling loop, recurring hierarchy scan, new WKUserScript, generic form recolor or image filter is added. This is static CSS in the existing checkout document-start program.

See `AUDIT-v7.400.md` and `COMMANDS.md`.

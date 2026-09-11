# AmazonDark v7.400 — Delivery Instructions completion audit

## Base
- Direct parent: `7.399~add-address-form-completion`.
- v7.399 Add-an-address completion and all v7.398-or-earlier behavior are preserved.
- Evidence: `AmazonDark-v7.399-ui-full-probe-20260910-220700-123-r1.zip`, cross-checked against the pre-mounted hidden `.ma-cdp-form` states in v7.398 FULL r5/r6.

## Why v7.399 did not affect this menu
v7.399 correctly targeted the Add-an-address family under `#address-ui-widgets-enterAddressFormContainer`. The reported Delivery Instructions screen is a different renderer family entirely: a separate `.a-popover.a-popover-secondary` whose content contains `.ma-cdp-form`. Therefore the v7.399 selectors had no matching ancestor on this screen and could not recolor it.

The r5/r6 probes already exposed this CDP tree while hidden. That evidence should have been used when the menu was first requested; v7.400 corrects that omission by owning the pre-mounted family, not by adding a broad checkout sweep.

## Probe-backed paint owners
The open v7.399 FULL capture shows:
- stock-white secondary popover/wrapper/inner and `a-secondary-view-inner` surfaces;
- stock-light `.a-popover-header-secondary` Back strip;
- white `.ma-attribute-group-expander` cards with light-gray expander headers;
- dark neutral headings/labels on those bright floors;
- white wrappers around the otherwise already-dark security-code and call-box inputs;
- dark secondary/helper copy that becomes unreadable where surrounding floors were already black;
- a yellow `.ma-cdp-form-save-button` inconsistent with AmazonDark's existing oval-button treatment.

The pre-mounted r5/r6 trees also expose property-type, dropdown/toggle, free-text, validation and edit/close states belonging to the same stable `.ma-cdp-form` renderer.

## v7.400 treatment
- Popover/wrapper/content/header floors: OLED black.
- Back/header neutral text and page-back glyph: light.
- Accordion owners/header/content: OLED black, standard gray structure, light prompts/labels and light expand/collapse glyphs.
- Neutral CDP copy: `#e8e6e3`; secondary/tertiary helper copy: `#b1aaa0`.
- Links and explicit semantic error/success states remain authored.
- Security/call-box/instruction wrappers: `#181a1b`, `#747a7c` edge, transparent child input, Amazon-blue focus cue.
- Property-type/dropdown/toggle/close controls: `#303335` neutral control floor and standard gray edge when unselected; selected Amazon-blue property state is not overwritten.
- Save/Edit primary oval controls: OLED black, `#747a7c` edge, light text; existing geometry/radius is retained.
- Warning/error card floors: OLED black while authored red/orange semantic edges remain untouched.
- Radio/checkbox sprites: explicitly preserved.

## Runtime / performance
The release adds static CSS only to the existing checkout document-start stylesheet. It adds no MutationObserver, interval, timeout/polling loop, RAF loop, Web scroll listener, recurring DOM/native hierarchy scan, new WKUserScript family, image filter, navigation mutation, or transition overlay.

## Device verification
After install, reopen Delivery Instructions and verify:
1. Back strip and the full page/popover are OLED black.
2. Both accordion cards and their expanded bodies are OLED black with gray separators.
3. All neutral headings/labels are light; helper text is readable gray; authored blue links remain blue.
4. Security code and Call box controls are dark with gray edges.
5. Save instructions is the standard AmazonDark black oval with gray edge and light text rather than yellow.
6. Expand/collapse, radio and checkbox artwork remains correct.
7. Property-type/edit/dropdown/business-hours/dog-risk and validation states remain dark when exposed.

## Probe-handoff maintenance found during release validation
The v7.392 family-based receipt discovery still carried a literal upper bound of `399`, and the skeleton helper's package gate still named v7.399 after the release bump. That would have rejected a valid v7.400 current receipt/package even though the universal probe payload itself had been version-bumped. v7.400 removes that future drift point by deriving the receipt upper bound from the current helper version (`CUR=${VER#7.}` / `AD_PROBE_CUR=${AD_PROBE_VERSION#7.}`) and updates the package gate to v7.400. The focused real-helper handoff regression passes with the current receipt and historical upgrade receipts.

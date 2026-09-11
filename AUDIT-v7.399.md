# AmazonDark v7.399 — Add-address form completion audit

## Base
- Direct parent: `7.398~legal-help-completion`.
- Evidence: `AmazonDark-v7.398-ui-full-probe-20260910-214421-819-r1.txt`.
- Universal FULL/VIEWPORT and transition probes are preserved and bumped to v7.399.

## Probe-backed menu identification
The WebUI root is checkout and the active form is `#address-ui-widgets-enterAddressFormContainer`. The capture shows the existing theme already owns the page/nav floors, heading/labels, input text, country/state controls, delivery-instructions control, checkbox presentation and checkout Continue button.

## Residual bright owners
1. Six visible `.a-input-text-wrapper.addrui-form-text-input-container` shells are `rgb(255,255,255)` with stock gray edges. Their child input elements are already `rgb(24,26,27)` with light text. The same wrapper family also exists on the hidden Urbanization contingent field.
2. The mounted `.a-box.a-alert.a-alert-warning` is white, as is its `.a-box-inner.a-alert-container`; its warning edge is authored orange and its text is already light.

## v7.399 correction
- Scope all changes beneath the exact Add-address form root.
- Make the addrui input wrapper `#181a1b` with a `#747a7c` edge.
- Make non-checkbox/non-hidden child text inputs transparent so the wrapper and input read as one surface.
- Preserve a blue `#007185` focus edge via `:focus-within` rather than flattening interaction state.
- Make only the warning box floor and inner floor OLED black. Do not set its border color, preserving Amazon's orange semantic warning edge.

## Preserved behavior
- Existing clear/dropdown glyph treatment.
- Checkbox artwork and disabled/default semantics.
- Location detection success/error shells from v7.395.
- Authored links and semantic colors.
- Field dimensions, layout and input behavior.
- Bottom Continue control.
- v7.396 native AMIWebViewController transition seal and all later checkout/help fixes.

## Runtime architecture
Static CSS only inside the existing checkout document-start stylesheet. No new observer, timer, RAF, polling, Web scroll listener, recurring hierarchy scan, extra WKUserScript or generic media filter.

## Device verification
Re-open Add an address and verify: no white field shells at any scroll position; warning floor OLED with orange edge retained; focused input still visibly selected; country/state, checkbox, delivery instructions and Continue remain unchanged.

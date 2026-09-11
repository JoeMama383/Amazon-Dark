# AmazonDark v7.401 — native payment sheets + press-state completion

v7.401 is built directly on `7.400~delivery-instructions-completion` and preserves the completed Delivery Instructions renderer, Add-an-address form, legal/help coverage, checkout/address transition seal, pickup UI, keyboard/accessory fixes, sponsored ownership, universal probes, and the established low-overhead performance architecture.

This release closes the two native React Native payment sheets captured in the supplied v7.398 FULL r5/r6 probes and adds a permanent interaction-state rule for already-owned neutral text/touch rows.

The r5 payment-entry sheet is a native `RCTView#bottom-sheet` in `AppCXWindow`. Its stable payment markers are `card-pressable-wrapper > ... > card-wrapper` and `input-pressable-wrapper > ... > input-wrapper`; the probe also shows stock-white `RCTSinglelineTextInputView` interiors, dark neutral labels, a yellow full-width oval action, and a neutral privacy glyph. v7.401 makes the sheet OLED, uses the existing dark control fill + gray edge for the two inputs, converts the yellow primary action to the standard AmazonDark black/gray oval treatment, lightens only neutral text, and makes only the probe-proven neutral vectors visible. Payment/card artwork is untouched.

The r6 payment-method chooser is another native `RCTView#bottom-sheet`, identified by the five `creatable-sleeve-*` row families. Its selected/pressed row is the probe-captured pale `*-content-wrapper-outline`. v7.401 keeps the sheet OLED, neutral text light, row separators gray, chevrons visible, and neutral pressed/selected row fill dark. The payment logos/images remain authored and are not filtered.

The new interaction-state policy also prevents Amazon's stock `.a-touch-press` / `:active` painter from turning already-themed AUI text rows white during touch-down. It is scoped to renderer families AmazonDark already owns: Delivery Instructions, Add-an-address touch rows, Help/topic/submenu/suggestion rows, plus the existing Subscribe checkbox and checkout delivery-option families. Authored semantic selection colors and checkbox/radio sprites remain untouched. Native React payment rows are protected through the existing `RCTView -setBackgroundColor:` event path, so a near-white press repaint is reclaimed immediately without polling.

No MutationObserver, interval, RAF loop, Web scroll listener, polling loop, recurring hierarchy scan, generic bottom-sheet recolor, image sweep, or new WKUserScript is added. The one new native payment-sheet bootstrap is a bounded one-time pass after an exact payment marker proves ownership; normal steady-state handling remains event-driven.

See `AUDIT-v7.401.md` and `COMMANDS.md`.

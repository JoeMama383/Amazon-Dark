## v7.539 — keyboard handoff evidence

Diagnostic update based on the v7.538 capture. Deduplicates unchanged native traits, uses a rolling bounded budget and observes legacy appearance reads. Expanded focused-input evidence. This is not a confirmed keyboard repair. See REVIEW-v7.539.md and COMMANDS.md.

# v7.539 — Keyboard transition diagnostics

Diagnostic build based on v7.537. Adds bounded, opt-in input-trait and focus evidence for the observed dark-to-white keyboard transition; does not claim to fix its unproven cause. See REVIEW-v7.539.md and COMMANDS.md.

# v7.537 — Interests WebKit extended keyboard fix

Direct parent: v7.536. The v7.535 transition showed the Amazon-side keyboard host and remote placeholder remain OLED black while the visible keycaps later revert. Public WebKit source shows the modern async text-input path uses `WKExtendedTextInputTraits`; its `restoreDefaultValues` explicitly writes `UIKeyboardAppearanceDefault`. v7.536 guarded only the legacy `UITextInputTraits` path, so it could not stop that modern-path reset.

v7.537 removes the speculative concrete-class runtime replacement and instead owns the exact WebKit extended-traits class. `WKExtendedTextInputTraits` now clamps `setKeyboardAppearance:` to Dark while AmazonDark is enabled, and reapplies Dark immediately after `restoreDefaultValues`. Legacy WebKit traits remain forced dark as before. There is no polling, timer, DOM traversal, modal geometry change, or keyboard hierarchy scan.

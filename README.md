## v7.540 — legacy keyboard traits clamp

The expanded v7.539 transition finally captured the keyboard handoff on iOS 17.0: `WKExtendedTextInputTraits` is absent, while multiple live `UITextInputTraits` objects are read with `UIKeyboardAppearanceDefault` during the invisible-input -> textarea handoff and repeated keyboard-show cycle. v7.540 keeps the diagnostic trace but clamps the legacy traits getter and setter to `UIKeyboardAppearanceDark` while AmazonDark is enabled. No modal geometry/CSS, DOM traversal, polling, timers, or keyboard hierarchy scans are added. See REVIEW-v7.540.md and COMMANDS.md.

## v7.539 — keyboard handoff evidence

Diagnostic update based on the v7.538 capture. Deduplicates unchanged native traits, uses a rolling bounded budget and observes legacy appearance reads. Expanded focused-input evidence. This is not a confirmed keyboard repair. See REVIEW-v7.539.md and COMMANDS.md.

# v7.539 — Keyboard transition diagnostics

Diagnostic build based on v7.537. Adds bounded, opt-in input-trait and focus evidence for the observed dark-to-white keyboard transition; does not claim to fix its unproven cause. See REVIEW-v7.539.md and COMMANDS.md.

# v7.537 — Interests WebKit extended keyboard fix

Direct parent: v7.536. The v7.535 transition showed the Amazon-side keyboard host and remote placeholder remain OLED black while the visible keycaps later revert. Public WebKit source shows the modern async text-input path uses `WKExtendedTextInputTraits`; its `restoreDefaultValues` explicitly writes `UIKeyboardAppearanceDefault`. v7.536 guarded only the legacy `UITextInputTraits` path, so it could not stop that modern-path reset.

v7.537 removes the speculative concrete-class runtime replacement and instead owns the exact WebKit extended-traits class. `WKExtendedTextInputTraits` now clamps `setKeyboardAppearance:` to Dark while AmazonDark is enabled, and reapplies Dark immediately after `restoreDefaultValues`. Legacy WebKit traits remain forced dark as before. There is no polling, timer, DOM traversal, modal geometry change, or keyboard hierarchy scan.

## v7.545 — keyboard private-state transition probe

Direct parent: v7.543.

The v7.543 device trace proves the effects-window fix held: `UITextEffectsWindow`, `UIInputSetHostView`, `_UIRemoteKeyboardPlaceholderView`, `UIKeyboardDockView`, `UIKeyboardAutomatic`, and the `UIKeyboardImpl` text-input traits all remained Dark through the period in which the visible keycaps still flipped light. The first responder `WKContentView`, however, still reports a Light trait collection, and UIKit exposes separate responder-styling machinery such as `responderStylingTraitsForceEditingMask:` / `updateStylingTraitsIfNeeded`.

v7.545 is diagnostic-only. It preserves all v7.543 production behavior and expands only the opt-in transition probe. Around keyboard show/change events it now records filtered private ivars/getters for the first responder, `UIKeyboardImpl`, active keyboard, remote keyboard window/scene, scene delegate, and input/effects controller; method type encodings for the relevant styling/remote-trait methods; a bounded runtime inventory of keyboard/remote classes; and extends delayed snapshots through 6.5 seconds. No modal CSS, geometry, keyboard traits, responder state, hierarchy, timing, polling, or production scans are changed.

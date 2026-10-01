# v7.543 validation

Evidence basis: the v7.542 transition capture reproduced the delayed keyboard failure while the expanded consumer probe remained active. Across the full keyboard handoff, WKContentView/UITextInputTraits report keyboardAppearance=Dark, UIKeyboardImpl textInputTraitsAppearance=Dark, UIKeyboardAutomatic is Dark, and UIInputSetHostView/_UIRemoteKeyboardPlaceholderView/UIKeyboardDockView report Dark. UITextEffectsWindow alone remains explicitly Light (traitStyle=1, overrideStyle=1) through all bounded post-show snapshots.

v7.543 therefore clamps only UITextEffectsWindow to UIUserInterfaceStyleDark. It does not change Interests modal CSS or geometry, keyboard frames, WebKit DOM behavior, input contents, polling/timers, or the existing legacy UITextInputTraits clamp. The v7.542 keyboard-consumer transition evidence remains active under the new release identity so the device retest can verify that UITextEffectsWindow becomes Dark.

Validation on final source tree:
- scripts/lint-logos.sh: PASS
- Objective-C++ syntax guard: PASS
- scripts/ui-probe.sh shell syntax: PASS
- scripts/skeleton-probe.sh shell syntax: PASS
- v7.543 keyboard-window-style regression: PASS
- exact scripts/validate.sh version-token normalization reproduced on a temporary tests copy: 199/199 test_*.py PASS in bounded sequential batches
- AD_STRICT_VALIDATE=1 sh scripts/validate.sh: began cleanly and passed the early regression set but exceeded the sandbox command-time limit before completing; no full strict-pass claim is made from that wrapper
- Tweak.xm: 855783 bytes (<856000 gate)

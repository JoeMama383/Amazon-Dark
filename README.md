## v7.543 — keyboard effects-window style fix

Direct parent: v7.542.

The v7.542 consumer trace finally exposes a concrete appearance mismatch after the delayed Interests keyboard handoff: the first responder traits, UIKeyboardImpl traits, active UIKeyboard object, input host, remote placeholder and dock all remain Dark, but `UITextEffectsWindow` remains explicitly Light (`traitStyle=1`, `overrideStyle=1`) through every bounded post-show snapshot.

v7.543 fixes only that mismatch. The private keyboard effects window is clamped to `UIUserInterfaceStyleDark` on later override writes and during layout. No Interests modal CSS, geometry, DOM work, timers, polling or hierarchy scans are added. The v7.542 transition consumer snapshots remain in place so a device retest can prove whether the window stays Dark after the previously failing handoff.

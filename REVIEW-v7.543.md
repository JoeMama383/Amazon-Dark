# v7.543 — keyboard effects-window style fix

The v7.542 transition capture is materially better than the earlier traits-only traces. Across all three keyboard show/recreation bursts, `WKContentView` text-input traits report keyboardAppearance=Dark, `UIKeyboardImpl` textInputTraitsAppearance remains Dark, `UIKeyboardAutomatic` is Dark, and the input host/remote placeholder/dock are Dark. The one persistent mismatch is `UITextEffectsWindow`, which reports both `traitStyle=1` and `overrideStyle=1` (Light) from the first show through the delayed handoff.

That mismatch fits the observed symptom: the keyboard initially paints with Dark keycaps from keyboardAppearance, then the remote/portal presentation settles into a Light effects-window environment and the visible key skin reverts. v7.543 therefore clamps only `UITextEffectsWindow` to Dark. It does not modify modal geometry, WebKit DOM/CSS, input content, keyboard frames, or the existing legacy-traits clamp.

The v7.542 consumer probe remains unchanged apart from release identity, so if the device still reproduces the problem the next trace will tell us whether the effects window was successfully held Dark.

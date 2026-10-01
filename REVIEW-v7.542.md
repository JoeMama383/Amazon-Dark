# v7.542 — keyboard consumer transition probe

The v7.539 trace was useful but incomplete. It proved that fresh legacy `UITextInputTraits` objects could report Default during the Interests hidden-input → textarea handoff. v7.540/v7.541 clamped those objects to Dark, yet the device still changes from the correct OLED keyboard to light keycaps. Therefore the reset observed in v7.539 is an upstream symptom, not the final consumer that chooses the remote keycap skin.

v7.542 does not change the production keyboard policy or the Interests modal. It expands TRANSITION evidence at the UIKit consumer boundary. On keyboard show/hide/frame notifications it records the current first responder, UIKeyboard/UITextEffectsWindow/input-host trait styles, and a read-only `UIKeyboardImpl` snapshot when available. It also records a one-time filtered method inventory for appearance/trait/style/delegate/input-mode selectors so the target iOS 17.0 runtime can tell us which private consumer API actually exists.

Because the bad keycap skin appears after the keyboard initially looks correct, WillShow/DidShow trigger bounded follow-up snapshots at 50, 200, 600, 1200 and 2000 ms. There is no recurring timer, polling loop, hierarchy mutation or production-time scan; this exists only while an explicitly armed transition probe is active.

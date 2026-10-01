# v7.546 — WebKit editing trait repair

Baseline: origin/main 63a8dff1, v7.545; GitHub Actions run 36892542908 succeeded.

Independently reviewed the raw v7.543 and v7.544 transition archives. The v7.544 archive contains 54 private-state and 64 consumer snapshots. The actual WKContentView responder reports Light, while effective legacy keyboardAppearance, the keyboard effects window, remote window, active keyboard and UIKeyboardImpl report Dark. The remote scene is also Light, but that alone does not prove it selects the skin. Earlier claims that either legacy traits or the effects-window mismatch was the final cause were not confirmed by the device.

Repair candidate:
- Set a native Dark appearance on WKContentView before the original becomeFirstResponder call, so the editing responder's environment agrees with the already-Dark keyboard policy.
- Save its pre-editing override once, retain later external style requests while editing, and restore the requested style after successful resignation. Failed focus acquisition also releases the override unless the view is still first responder.
- Restrict this lifetime to the focused WebKit view; no application/window/scene-wide new override, input replacement, geometry writes, responder cycling, or reloadInputViews.
- Keep all existing keyboard clamps and v7.545 diagnostics to allow comparison.

Evidence improvement:
- Read exact _keyboardAppearance/keyboardAppearance scalar ivars when their encodings and object bounds support safe reads. Report null when unavailable. Never write the ivar or invoke an appearance getter for this stored value.
- Add stored values to trait events and consumer trait-child snapshots. Existing effective values remain separately available. This avoids mistaking our own getter's Dark return for the stored state.
- Extract three identical guarded owner-trace calls to one helper, preserving their behavior and the source-size gate.

Apple documents overrideUserInterfaceStyle as the view/subview appearance override. This is a standard UIKit environment repair, not an invented private scene setter. Sources reviewed: https://developer.apple.com/documentation/uikit/uiview/overrideuserinterfacestyle and https://developer.apple.com/videos/play/wwdc2023/10057/ . Upstream OledKeyboard code paints backing surfaces but does not select remote keycap appearance; repainting that floor again would not address the observed mismatch.

Not proven: whether native responder style is the final cause of the visible flip. We cannot run this jailbroken device here. The next capture must verify firstResponder.traitStyle=2 through the hidden-input/textarea handoff and compare stored/effective traits if keys still change. The probe remains app-local and cannot observe remote keycap pixels.

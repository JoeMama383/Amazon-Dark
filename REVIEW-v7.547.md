# v7.547 review

The failing GitHub test is not a false positive. It proves the v7.546 handoff archive and the existing-clone regression inventory diverged. `test_v7546_webkit_editing_trait_repair.py` remained in the clone after the overlay copy, but the source ZIP lacked the `ADWebKeyboardStyle7546` implementation it was written to protect.

v7.547 restores that contract on exact `WKContentView`: Dark native trait style is established before `%orig` in `becomeFirstResponder`, reasserted while the responder remains active, and the pre-edit override style is restored after a successful resign. Existing WebKit input-trait darkening remains in place. The helper does not own frames, bounds, transforms, modal geometry, or recurring work.

The v7.546 Menu FULL dispatcher change is preserved independently.

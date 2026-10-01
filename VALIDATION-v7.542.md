# v7.542 validation

Evidence basis: v7.541 still reproduces the delayed light-keycap keyboard failure after the legacy UITextInputTraits clamp. The existing v7.539 transition trace therefore identified an upstream traits reset but did not prove the final UIKit/remote-keyboard consumer that selects keycap appearance.

v7.542 is diagnostic-only. It keeps the v7.541 production keyboard and Interests modal behavior unchanged and expands the explicitly armed transition probe to record bounded keyboard-consumer snapshots at WillShow/DidShow plus 50/200/600/1200/2000 ms follow-ups. Captured state is limited to technical classes/pointers, scalar appearance/type/style values, first-responder identity, input/delegate object classes/pointers, host/placeholder style state, and a filtered UIKeyboardImpl method inventory when that class exists. No typed text, URLs, keycap pixels, hierarchy mutation, keyboard writes, or recurring polling are added.

Validation on final source tree:
- scripts/lint-logos.sh: PASS
- Objective-C++ syntax guard: PASS
- scripts/ui-probe.sh shell syntax: PASS
- scripts/skeleton-probe.sh shell syntax: PASS
- v7.542 keyboard-consumer probe regression: PASS
- exact scripts/validate.sh version-token normalization reproduced on a temporary tests copy: 198/198 test_*.py PASS in six sequential batches
- Tweak.xm: 855926 bytes (<856000 gate)

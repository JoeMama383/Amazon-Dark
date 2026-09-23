# v7.457 — interim diagnostic handoff

Based on origin/main 615ba69c (v7.455), incorporating the local v7.456 repair. Not pushed or installed by the assistant.

Purpose: retain automatic PDP scan recovery while identifying Amazon's screenshot Share handler. The new code passively records bounded screenshot observer registrations and preserves all registration arguments, callbacks and returned tokens. It does not suppress notification delivery or prevent Share opening. The temporary close toggle defaults ON; OFF explicitly stops PDP FULL.

132 Python test entrypoints pass in the available environment, including modeled Share recovery and passive-registration source contracts. Shell syntax and git whitespace checks pass. Three clang-dependent tests cannot run because clang is unavailable; full strict validation and iOS compilation are NOT claimed. Real-device validation is pending.

Cold relaunch Amazon after installing, screenshot a product page, allow FULL to finish, then export from the terminal. FULL and VIEWPORT now include SCREENSHOT_OBSERVER_REGISTRATIONS. Empty evidence means no matching registration was observed after hook installation; it must not be interpreted as proof that there is no screenshot listener. Registration evidence does not prove callback delivery. No blanket notification suppression or guessed private selector was installed.

All three probe archive formats remain plain TAR. Outstanding ad/UI issues remain open. Historical VALIDATION-v7.456.md describes the underlying recovery fixture and five captured modal locks.

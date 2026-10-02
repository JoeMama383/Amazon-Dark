# v7.555 — combined Filters / Settings / Interests validation

Baseline: current public GitHub origin/main, commit 9a0a45ce (v7.554), fetched successfully using network-enabled execution. Restored the full exact Filters CSS block from commit 634ac270 (v7.553), not a reconstructed approximation.

The failure was a missing merge: v7.554 overlaid v7.551 source and replaced the exact v7.553 Filters selectors with older generic selectors, while the newer v7.553 regression remained in the phone/GitHub checkout. Its assertion correctly caught the absent #dropdown-content-s-all-filters owner.

Restored behavior:
- Medium-gray #303335 option controls, white text, #747a7c borders.
- One continuous #494d4d vertical divider on the left rail.
- Removal of both footer dividers and their pseudo-element paint.
- OLED Show-results button, white text, gray border.
- Exact Filters owners and authored star/Prime glyphs retained.
- v7.554 App Settings and keyboard native implementation retained byte-for-byte, except the runtime version string in Tweak.xm.
- Interests document-owned stylesheet retained. Its extraction boundary now points to the restored Filters block.
- Numeric Tweak.xm source-size ceiling remains removed.

Validation:
- 208 normalized regressions PASS, including the previously failing test_v7553_filters_exact_owners_no_tweak_size_gate.py, the v7.553 exact Filters test, and the executable Interests hydration/reinjection test.
- Two native compiler preflights BLOCKED because clang/clang++ are unavailable locally; not counted as passes.
- Full restored Filters source block equals commit 634ac270 after normalizing its comment version.
- Logos lint, shell syntax, delivery shell syntax, active version identities, and git diff --check PASS.
- iOS native compilation/package and device visual verification remain for GitHub CI/device testing.

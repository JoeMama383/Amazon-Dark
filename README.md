# AmazonDark v7.466 — legacy PDP CI anchor compatibility

Direct parent: **v7.465~pdp-ad-book-ci-fix**.

v7.465 cleared the earlier `ADAddressManagementJS7412()` boundary failure, and strict CI then advanced through the complete v7.438 regression before stopping in `test_v7439_pdp_ui_completion.py`. That test slices `ADPDPSafeFrameJS7432()` at the historical `// v7.439:` source marker. v7.464 had removed that marker while compacting source comments.

v7.466 restores the minimal `// v7.439:` boundary immediately before `ADPDPUICompletionJS7439()` and restores the exact historical OLED declaration token that the same v7.439 regression verifies. It also restores the minimal `// v7.388: WKUserScript` boundary before `ADSharedUserScript7387()` so the older user-style source-contract slicer cannot fail for the same reason later.

These are source-contract compatibility repairs. The v7.464/v7.465 production UI ownership remains intact: top standalone-ad header/floor treatment, Books divider, Book-details fade/text, Customer-review text, half-carousel OLED/text controls, BTF duplicate-border removal, image taming, and all-frame delivery. The added `background-color:#000` / `background-image:none` declarations are behaviorally consistent with the already-owned OLED ILM shell.

No MutationObserver, polling loop, RAF loop, Web scroll listener, or recurring DOM walk is added. FULL, VIEWPORT, and TRANSITION identities are regenerated as v7.466.

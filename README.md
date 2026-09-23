# AmazonDark v7.467 — strict PDP compatibility repair

Direct parent: **v7.466~pdp-ad-book-ci-compat**.

v7.466 failed the frozen v7.448 performance-consolidation regression because it reintroduced a CSS redundancy (`background` immediately followed by the equivalent `background-color`) while trying to satisfy an older v7.439 source-contract assertion. The v7.448 history already updated that v7.439 assertion to accept the consolidated shorthand, so restoring the redundant declaration was incorrect.

v7.467 keeps the restored historical slicing markers (`// v7.439:`, `// One immutable document-start program...`, and `// v7.388: WKUserScript`) but restores the actual v7.448 CSS consolidation contract. The ILM shell again uses the single `background:#000!important` shorthand. The Book-details fade uses `background:none!important`, which preserves the requested transparent/no-image result without tripping the v7.448 redundant-background detector.

The v7.464 UI fixes remain intact: standalone-ad header/floor treatment, gray Books divider, transparent Book-details fade, white Book-details/review copy, OLED half-carousel treatment, BTF duplicate-border removal, and all-frame PDP delivery. No MutationObserver, polling loop, RAF loop, Web scroll listener, or recurring DOM traversal is added.

The new v7.467 regression reproduces both regex checks from the frozen v7.448 performance test and also verifies all three restored historical source boundaries in the same run.

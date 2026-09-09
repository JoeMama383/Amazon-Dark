# AmazonDark v7.384 — sponsored Logos build fix

Direct parent: v7.383 sponsored-selector rules.

v7.383 contained the intended sponsored-content selector correction, but GitHub Actions never reached Clang because the Logos preprocessor aborted at the closing brace of the very large `ADKillerSponsoredJS...` function in `Tweak.xm`. The same function parses cleanly when compiled directly as Objective-C.

v7.384 changes the compile boundary only:
- moves the sponsored CSS payload/function to `src/ADSponsored.m`;
- leaves `Tweak.xm` with a small external declaration and the same document-start injection;
- adds `src/ADSponsored.m` to `AmazonDark_FILES`;
- preserves v7.383 selector semantics, the v7.381 OLED Home ad-loading floor, and v7.382 mixed-carousel precision;
- keeps sponsored filtering declarative with no MutationObserver, recurring scanner, timer, RAF loop, or scroll hook.

No launch/switcher ownership, checkout/BYG theming, Price History logic, universal UI probes, or other production theming behavior was intentionally changed.

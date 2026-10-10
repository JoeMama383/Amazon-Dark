# AmazonDark v7.623 — actual CI compiler-fixture repair

**Parent:** v7.622 `alexa-feedback-native-web` source.

## Root cause

The exact GitHub failure was in `test_v7597_live_thankyou.py`: its standalone Objective-C++ fixture extracts source from `static BOOL ADCXINeutralButton7597` through `%ctor`, translating only the existing `CXIHighlightableTouchAreaButton` Logos hook. v7.622 inserted another `%hook UIActivityViewController` into this extraction interval. Consequently unprocessed `%hook`/`%end` directives were handed directly to clang++, producing `expected unqualified-id`, `missing context for method declaration`, and `@end must appear in an Objective-C context`.

## Minimal source correction

- Move the **existing, unchanged** `UIActivityViewController` dark-style Logos hook to the file-scope preceding `ADCXINeutralButton7597`, outside the regression fixture's extraction interval. No change to what the hook does.
- Add `tests/test_v7623_share_hook_compile_regression.py`, which reruns the **original failing native fixture's actual clang++ compilation** and asserts that the share hook cannot be captured there again.
- Bump runtime/probe/helper identity consistently to `7.623~alexa-ci-compile-repair` and update `COMMANDS.md` existing-clone stage folder to `ad7623`.
- Preserve all five v7.622 Alexa/share/feedback UI theme modules and v7.621 Orders/Shipping and v7.620 Orders/Ad-privacy modules without modifications.

**No visual styling, raster, probe walker, rendering geometry, or taming changes.** The original `ADNewMenus7622.js` / `.js.inc` bytes are unchanged.

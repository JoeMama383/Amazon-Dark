# AmazonDark v7.615 — Native compile repair

Parent: complete v7.614 source (including v7.606–v7.613 UI/probe work).

## Fixes

- The v7.612 Live owner block in `src/Tweak.xm` calls two `static` functions before their definitions. Added forward declarations for `ADMenuButtonBorder7255(void)` and `ADPersonTextStorage7206(UIView *)` before the Live block, which is required in Objective-C++.
- `ADClassNameIs7183` expects a C string (`const char *`). Changed three newly introduced Live class matches from Objective-C `@"ClassName"` objects to `"ClassName"` string literals. These are real compile-time type mismatches in Objective-C++.
- Added targeted test `tests/test_v7615_live_native_compile_contract.py` for order and literal types, including a standalone clang++ gnu++98 syntax fixture; no runtime UI paint logic changed.
- Synchronized the package identity and FULL/VIEWPORT/TRANSITION/performance/SpringBoard emitters to v7.615.
- Existing native warning messages about block retain cycles originate from inherited FULL scanning; not compiler errors and not touched here.

## Limitations

The original user-supplied log excerpt contained the compile summary and 6 warnings, but not the 6 underlying `error:` diagnostics. These corrections address clear invalid native callsites found directly in the source. This environment lacks Theos/iOS SDK, so only GitHub CI can certify the complete iOS target build.

# AmazonDark v7.618 — changes from v7.617

## Fixes proven by uploaded GitHub compiler log

1. `src/Tweak.xm:4309`, **undeclared `ADMenuButtonFill7255`**: Added the missing typed forward declaration above the existing v7.612 Live helper block, before the profile picker code that calls it. Retains the existing definition and return value.
2. `src/Tweak.xm:10348`, **undeclared local `liveText`**: Declared the Live-ownership boolean in the proper scope of `RCTTextView -setTextStorage:contentFrame:descendantViews:` and applied existing neutral-text storage conversion before calling the original setter. Restores the intended post-commit Live paint path.
3. `src/Tweak.xm:2675`, **insufficient Objective-C string-format arguments**: Two `%d` + three `%.3f` conversions had only four data arguments. Added the fifth `f` argument. No CSS/JS source strings or preference logic altered.
4. Versioned the UI, performance, and skeleton probe metadata/scripts to v7.618, plus package metadata and handoff documentation. Universal scan behavior is unchanged.
5. Added `tests/test_v7618_actual_compiler_diagnostics.py`, which checks declaration ordering and scope against the exact source, format arity, and separately compiles the isolated relevant ObjC++ snippets with local clang.

## Scope & caveats

- **No UI CSS changes, probe traversal rewrites, or route-specific scan dispatchers.** All prior changes remain in place.
- Full iOS Theos compile requires GitHub's macOS/iOS SDK. The local Linux `clang++` test is an isolated syntax check, not a replacement for an end-to-end Theos build.
- The uploaded log contains ARC retain-cycle warnings in `ADUniversalUIProbe7362.inc`. These are not compilation errors and are left unchanged here to avoid introducing unverified scanner changes.

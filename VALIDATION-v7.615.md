# AmazonDark v7.615 — Validation

**PASS — strict source validation:** `AD_STRICT_VALIDATE=1 sh scripts/validate.sh` returned exit code **0** with **272/272 Python regressions passing** (including v7.606–v7.615 post-probe tests). `lint-logos: OK` and all UI probe version checks passed.

**PASS — new native compiler-contract test:** `tests/test_v7615_live_native_compile_contract.py` checks the two Live owner function declarations appear before their callsites, checks that all three `ADClassNameIs7183` Live calls supply `const char*` string literals rather than Objective-C `NSString*` expressions, and runs a `clang++ -std=gnu++98 -Werror -fsyntax-only` fixture.

**Validation gap:** The pasted failed GitHub job only included the tail warnings, not the six original `error:` lines. The v7.614 source unambiguously contained these native compile errors, and v7.615 corrects them. An actual iOS Theos build cannot be performed in this environment because the iOS SDK/Theos are not installed; GitHub Actions must build to confirm. Source regressions and the isolated fixture do **not** certify a full iOS compilation.

**UI/runtime scope:** Native Live compilation repair and version/metadata synchronization only. No production UI selector, border/geometry or image-taming behavior changed relative to v7.614; inherited opt-in FULL/VIEWPORT/TRANSITION probe behaviors remain intact.

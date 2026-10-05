# v7.563 Pharmacy validation

Baseline: origin/main d021464c, v7.562~seller-messaging-oled-twb.
Evidence: supplied AmazonDark-v7.562-ui-full-probe-20261004-195413-755-r1.tar and IMG_7480.png.

- Logos lint, shell syntax and git diff whitespace checks pass.
- All-test runner using the shipped validation identity normalization: 214 pass; three compiler-dependent tests cannot run because clang/clang++ are absent (v7385 C linkage, v7480 Objective-C++ guard, v7562 Seller Messaging syntax).
- Strict validate.sh stops at the missing clang executable. No compiler gates were removed or bypassed in the shipped scripts.
- Pharmacy test executes emitted JavaScript at brightness 1.000, 0.900, 0.684 and 0.420; evaluates the CSS cascade with tinycss2/cssselect2/lxml; verifies scoped OLED floors, white copy, gray pills, buttons, and untouched Prime banner/unrelated content.
- CI also compiles the Pharmacy media helper when clang++ is present.
- Existing keyboard, Settings, Interests, Filters, Seller Messaging and probe implementations are retained. Probe changes are version identity only.

Native Theos build and physical-device first paint/refresh/navigation testing remain pending. This is a source release, not a verified compiled device package.

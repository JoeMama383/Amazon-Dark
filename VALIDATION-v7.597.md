# AmazonDark v7.597 validation

Strict source validation: **PASS — 252 Python regression scripts**, plus the wrapper's source, Logos and version/probe checks. No skipped regression is counted as a pass.

The new regression replays 640 sanitized captured DOM paint cases from the three supplied v7.596 probes. It verifies 38 floor cases, 29 text cases, 18 image/video cases and 8 semantic-color cases, plus search placeholder/entered-text icon parity, unrelated-root exclusions and preserved colored-text inheritance. Interactive placeholder state is modeled as a fixture attribute because cssselect2 does not implement that browser pseudo-class; the actual CSS relationship and cascade are evaluated.

Additional checks cover configured dimming at disabled/0/45/100 strength, exact JS/include equality, native Objective-C++/gnu++98 syntax with declaration stubs, bounded native glyph scope, logo color/alpha mapping, and 100 actual JavaScript reinjections producing exactly one stylesheet and one SVG filter definition with no recurring work. Existing performance recorder, cleanup, cache and probe export regressions pass unchanged.

The historical cache comment remains v7.596 so historical shared-core hash checks continue to verify the original code. Historical regression files were not rewritten to weaken behavior checks.

Environment: Linux, Python 3.12, Node, Clang via Zig 0.13, tinycss2/cssselect2/lxml. Source fixtures omit URLs, user text and tracking identifiers. Raw probes and screenshots are not included in the source package.

**Limits:** no Theos/iOS SDK or connected iPhone was available. Native syntax stubs do not validate Apple SDK ABI. There is no post-change device screenshot, probe or performance recording here. CI must build the installable package after the source is pushed, followed by on-phone visual verification, including the WebKit logo filter and player states.

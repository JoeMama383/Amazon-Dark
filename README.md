# AmazonDark v7.386 — sponsored C-linkage build fix

v7.386 is a narrow build-boundary correction on top of v7.384.

The large sponsored-content payload stays outside Logos in `src/ADSponsored.m`. A shared
`src/ADSponsored.h` now gives the Logos-generated Objective-C++ caller and the ordinary
Objective-C implementation the same C linkage, preventing arm64/arm64e symbol mangling
mismatches. Sponsored selector behavior, OLED ad-loading floors, price history, theming,
launch/switcher policy, and universal probes are otherwise unchanged.

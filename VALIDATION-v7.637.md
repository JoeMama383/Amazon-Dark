# v7.637 validation

- Full source regression suite: **298 scripts passed**.
- Actual removal-hook body executed in a C++98 fixture: **30 consecutive probe sessions** preserve the authored script order/count and receipts; ordinary app-driven removal still reinstalls the theme. The old unguarded sequence reproduces duplicate scripts.
- Actual shipped JavaScript recorder/wrapper executed in Node fixtures: startup/callback/style-read accounting, callback receiver/arguments/return/exception behavior, passive/once options, record caps, privacy and inactive cleanup passed.
- Optional style experiment: normal mode causes zero trial layout reads; explicit mode restores the prior sheet state on success/error and avoids work after backgrounding. Report labels separate experimental cost from input delay.
- All existing v7.636 theme-function string payloads and embedded JS includes match stored SHA-256 baselines after release-stamp normalization. The Order Details formatter now supplies its previously missing second argument without changing the intended CSS.
- Actual iOS 16.5 SDK / arm64 iOS 17 / Logos / Objective-C++98 syntax checks passed for Tweak, SpringBoard, preferences, and sponsored-content source. Zero compiler errors; the prior format-argument warning is fixed. Five inherited FULL-probe block-retain warnings remain.
- Source archive CRC, release identities and required diagnostic files verified.

No iPhone runtime, GPU rendering benchmark, or linked .deb was produced locally. GitHub Actions produces the linked package after the manual push; device confirmation is still required for the reported tap/swipe stalls. Passing source tests does not establish that those delays are eliminated.

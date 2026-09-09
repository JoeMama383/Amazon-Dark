# AmazonDark v7.385 — sponsored C-linkage build audit

## Failure isolated
v7.384 successfully moved the large sponsored selector payload out of Logos, so `Tweak.xm`
preprocessed and compiled. GitHub Actions then failed at link time because `Tweak.xm` is emitted
by Logos as Objective-C++, while `ADSponsored.m` is ordinary Objective-C. The old declaration in
`Tweak.xm` therefore requested the C++-mangled symbol for `ADKillerSponsoredJS7384()`, while
`ADSponsored.m` exported the unmangled Objective-C/C symbol `_ADKillerSponsoredJS7384`.

The linker diagnostic itself confirmed the mismatch:
`NOTE: found '_ADKillerSponsoredJS7384' ... declaration possibly missing 'extern "C"'`.

## v7.385 correction
- Added `src/ADSponsored.h`.
- The header wraps `ADKillerSponsoredJS7384(void)` in `extern "C"` only when compiled as C++.
- `Tweak.xm` and `ADSponsored.m` both import the same header.
- `ADSponsored.m` remains an ordinary Objective-C translation unit, keeping the large payload out
  of Logos.
- No sponsored selector, preference, injection-time, or rendering behavior is intentionally changed.

## Preserved behavior
- v7.383/v7.384 precision sponsored-selector rules remain unchanged.
- v7.381 OLED Home ad-loading floor remains unchanged.
- Price History remains unchanged.
- No MutationObserver, polling loop, recurring timer, RAF loop, or scroll scanner is introduced.
- No app-switcher cover or warm-splash suppression is introduced.
- `layout/DEBIAN/postinst` remains executable and is checked by validation.

## Build proof boundary
Local validation checks source structure, scripts, selector JS, tests, and a dedicated C/C++ linkage
contract. GitHub Actions remains authoritative for the real Theos arm64/arm64e compile, link, sign,
and package stages.

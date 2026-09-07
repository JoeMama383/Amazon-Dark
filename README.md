# AmazonDark v7.355~cart-same-day-search-strip-fix

Direct base: accepted `v7.354~search-carousel-store-spotlight-fix`. All v7.354 Search media/Store Spotlight work, v7.353 Top-reviewed repair, v7.352 product-action ownership, v7.351 optimization, Cart loader work, and v7.350 splash seal remain intact.

## Changes

- **Cart Same-Day Delivery incentive:** the current Cart probe identifies `#ssd-ca-buy-box` as the 430×126 light-blue owner. v7.355 makes that exact owner OLED black and flips its neutral copy to the standard light foreground. The `a-meter` track becomes black while Amazon's green `a-meter-bar` and green edge remain green.
- **Find eligible items:** the exact `#dex-basket-building-bottom-sheet-link` AUI button now uses the same Cart button palette already used elsewhere: `#303335` fill, `#747a7c` edge, light text, stock Amazon geometry/radius.
- **Search YOU MIGHT ALSO NEED title strips:** v7.354 successfully restored/tamed the carousel images but left the stock white title strip. v7.355 does **not** restore the rejected broad `cards_carousel_widget-sug-*` floor rule. It darkens only the structural sibling immediately following the `cards_carousel_widget-sug-im*` media owner, keeping media transparent/visible and brightness-tamed.
- No new hook, MutationObserver, timer, RAF, Web scroll listener, polling loop, or recurring DOM/native scan.

## Probe workflow

Screenshot or `SIGUSR2` triggers the current UI probe. Historical filenames remain `v7.309-*`, while the file header reports the installed v7.355 runtime.

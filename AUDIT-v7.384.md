# AmazonDark v7.384 — sponsored Logos build-fix audit

Direct parent: `7.382~sponsored-carousel-precision`.

## Root cause of the v7.382 all-sponsored-visible regression

v7.382 correctly narrowed ownership after v7.381 deleted mixed carousel cards, but two new dashboard rules used nested `:has()`:

`li:has(...div:has(...))`

Selectors Level 4 does not allow `:has()` inside another `:has()`. Those invalid selectors were placed in the same ordinary comma-separated selector list as every other blocker selector. Ordinary selector lists are unforgiving: one invalid selector invalidates the whole rule. The result was exactly the reported symptom — the toggle was enabled but no sponsored selector applied.

## v7.384 correction

1. Rewrites the dashboard single-creative/video ownership selectors to one legal `:has()` each.
2. Emits every sponsored/ad selector as a separate CSS rule. Even if Amazon introduces a future unsupported selector family, the rest of the blocker continues to work.
3. Restores the current AmznKiller selector-family coverage that the first partial iOS port omitted, including thematic bundles, `sb-*`, loom slots, featured-ASIN/video modules, APE/safe frames, order/ship/thank-you placements, and exact `isSponsoredProduct:true` matching.
4. Keeps only narrow AmazonDark-specific outer dashboard collapse for immediate explicit ad roots. It does not restore v7.381's broad mosaic/window ancestor promotion.
5. Retains AmznKiller's narrow whole-window ownership only for `single-creative-card` / `single-video-card` carrying the ad feedback label.

## Loading floor

The v7.381 probe-backed Home dashboard loading floor remains OLED at document start whether sponsored blocking is enabled or disabled:

`#gwm-dashboard > li.gwm-tile { background:#000!important; background-color:#000!important; }`

## Runtime/performance contract

The blocker is still one document-start stylesheet injection. There is no MutationObserver, interval, timeout, RAF loop, scroll listener, polling loop, recurring DOM scan, native hierarchy scan, warm splash suppression, app-switcher cover, or snapshot painter.

Price History, checkout dedupe, BYG, Cart/Search/Person/Alexa/Menu/TWB theming, cold splash ownership, teal switcher forensics, and universal VIEWPORT/FULL probes are otherwise unchanged except release identity.

## v7.384 compile correction
GitHub Actions stopped in the Logos preprocessing stage at the closing brace immediately following the large sponsored selector function. The extracted v7.383 function parses cleanly when sent directly to Clang, so this was not an unmatched Objective-C brace/string error in the payload itself. v7.384 removes the payload from the Logos input entirely: `Tweak.xm` declares `ADKillerSponsoredJS7384`, while `src/ADSponsored.m` contains the ordinary Objective-C implementation and is compiled through `AmazonDark_FILES`. Selector/runtime semantics are otherwise unchanged from v7.383.

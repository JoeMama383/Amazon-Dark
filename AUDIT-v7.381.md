# AmazonDark v7.381 — sponsored slot collapse + Home ad first-paint floor audit

Direct parent: `7.380~amznkiller-features-optimization-audit`.

## Probe evidence

The supplied v7.380 VIEWPORT probe and screenshot are sufficient to identify the visible white transition owner:

- Home dashboard card 1 is an outer `li.gwm-tile` at approximately `16,135.6 161x214.7`; the list item itself paints `rgb(255,255,255)`.
- Home dashboard card 2 is another `li.gwm-tile` at approximately `185,135.6 161x214.7`, also painting white. Its `md-grid-2` descendant is in the `mobile-gateway-atf_ad-...` family.
- The lower empty sponsored position is the center `_hp-mosaic-container_style_widgetContainer...` list item at approximately `67.8,402.3 326.8x467.8`. The center slot remains after the blocker has hidden its inner ad subtree.
- Neighboring non-ad cards use the same outer shell families, so the transition repair must paint the shell but must not generically delete the shell.

The viewport probe is not a frame-by-frame timing trace, so it cannot prove that no earlier browser frame exists before document-start scripts execute. It does prove the persistent white DOM owner. v7.381 therefore fixes that owner at document start; only if a white sub-frame survives on device would a narrower early-paint trace be necessary.

## Production changes

### Ads enabled: OLED transition shell

`ADHomeAdShellFloorJS7381` installs one tiny stylesheet at document start:

`#gwm-dashboard > li.gwm-tile { background:#000; background-color:#000; }`

It is appended to the existing immutable `ADCoreWebJS7271` payload, so this does **not** create another `WKUserScript`. The historical `ADFloorJS` payload remains byte-for-byte/source-hash identical to the accepted baseline.

### Hide Sponsored Content enabled: collapse owner, not child

`ADKillerSponsoredJS7381` keeps the v7.380 inner-ad selectors and additionally collapses the owning list item for three Home slot families:

- `#gwm-dashboard > li.gwm-tile`
- `#gwm-window > li.gwm-window-tile`
- `li[class*=_hp-mosaic-container_style_widgetContainer]`

The parent only qualifies when a positive ad descendant exists. The positive marker set is the same high-confidence metadata already used by the v7.380 blocker, plus the probe-captured `mobile-gateway-atf_ad-` family and the existing sponsored IDs/painters. Because CSS `:has()` still sees descendants that are `display:none`, the parent can collapse synchronously without a MutationObserver or repair scan.

The rule intentionally does **not** use a generic `[class*=sponsored]` predicate. The capture contains an ordinary card descendant named `_npack-asin-card_style_asin-sponsored-badge-empty__...`; treating that substring as proof would create false positives.

## Preservation

Unchanged production files include the preference bundle, preference plist, package plists, Makefile optimization flags, CI workflow, and validator. Price History remains unchanged. Checkout dedupe, BYG, Cart, Search, Person, Alexa, TWB, launch seal, teal transition forensics, and the two universal UI probe categories are preserved.

SpringBoard production policy is unchanged; only its current diagnostic/version identity moves to v7.381. There is still no app-switcher cover, warm-splash suppression, generic live-XIB replacement, snapshot deletion, or scene painter.

## Runtime/performance contract

New recurring work: **none**.

No MutationObserver, `setInterval`, `setTimeout`, RAF loop, scroll listener, polling loop, recurring DOM scan, new native hierarchy walk, network interception, or fake UI control is introduced. The new ad-shell floor is folded into the already-existing single core document-start WebKit program.

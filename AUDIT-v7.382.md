# AmazonDark v7.382 — sponsored carousel precision audit

Direct parent: `7.381~sponsored-slot-collapse-ad-floor`.

## Regression identified

v7.381 fixed the blank-shell symptom by promoting any matching sponsored descendant to the owning `li.gwm-tile`, `li.gwm-window-tile`, or Home mosaic list item. That was too broad. A mixed recommendation card can legitimately contain a nested sponsored product/feedback marker while the rest of the card is normal content. The v7.381 `:has(:is(...))` ownership rule therefore deleted the entire card and all of its normal contents.

A second precision bug was inherited from v7.380: the blocker matched any `data-a-carousel-options` containing the key `isSponsoredProduct`, regardless of whether the value was `true` or `false`. A normal carousel carrying `"isSponsoredProduct":"false"` could therefore be blanked.

## Upstream AmznKiller comparison

The current AmznKiller static list is materially narrower in the two areas that matter here:

- it matches `div[data-a-carousel-options*='"isSponsoredProduct":"true"']`, not mere presence of the key;
- it collapses a `gwm-window-tile` only for a `single-creative-card` or `single-video-card` that actually contains `[data-ad-feedback-label-id]`.

v7.382 adopts those ownership semantics rather than the v7.381 blanket descendant promotion.

## v7.382 production behavior

### Ads enabled

The successful v7.381 document-start Home loading-floor rule remains unchanged:

`#gwm-dashboard > li.gwm-tile { background:#000!important; background-color:#000!important; }`

This is still appended to the existing immutable core WebKit program. It adds no extra user script and does not hide any content.

### Hide Sponsored Content enabled

- Individual explicit sponsored/ad elements continue to collapse.
- `isSponsoredProduct` must now be explicitly `true`.
- `#gwm-window > li.gwm-window-tile` no longer collapses because of an arbitrary nested ad marker. Only the exact single-creative/single-video feedback-label ownership rule can collapse it.
- Home mosaic list items no longer use descendant-wide ad detection. They may collapse only when the immediate widget root is itself an explicit ad placement.
- Home dashboard list items similarly collapse only when their immediate widget root is an explicit ad placement, including the probe-confirmed `mobile-gateway-atf_ad-` family.
- Nested sponsored products inside a mixed recommendation card do not delete the whole card.

## Preservation / performance

Price History is unchanged. Checkout dedupe, BYG, Cart/Search/Person/Alexa/Menu/TWB theming, cold splash ownership, teal switcher diagnostics, and the universal VIEWPORT/FULL probes are unchanged except version identity.

No MutationObserver, interval, timeout, RAF loop, scroll listener, polling loop, recurring DOM scan, native hierarchy scanner, snapshot painter, or app-switcher cover is introduced.

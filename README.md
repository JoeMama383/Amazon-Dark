# AmazonDark v7.474 — PDP visible-copy + selected-format repair

Direct parent: **v7.473~standalone-survivor-sheet**.

The supplied v7.473 VIEWPORT is the acceptance evidence for this pass. It proves that the persistent survivor sheet is finally active inside the top standalone child frame (`survivor7473=1`, adopted survivor sheet present) and that the header leaves themselves are now white. The remaining misses are exact leaf/state ownership, not frame delivery.

## 1. Top standalone/offsite variants

The current v7.473 capture contains visible `brand-name`, `product-description`, and Sponsored copy; those current header leaves already compute white/gray correctly. It does **not** contain a separate visible price/rating row in that particular creative. Historical v7.463 r1 evidence from the same offsite renderer family does contain the alternate secondary row: `formatted-price`, `#symbolOne`, `#price-integer`, `#price-fraction`, ratings and stars.

v7.474 therefore extends the already-proven constructable survivor sheet rather than changing delivery again:

- `formatted-price` and its exact price leaves become white when that alternate row exists;
- inline-authored neutral black (`rgb(0,0,0)`, Amazon `rgb(15,17,17)`, `rgb(0,0,17)`, and `#000`) on ordinary offsite text leaves is promoted to white;
- the Sponsored selector remains later in the cascade and keeps its subdued gray ownership;
- Prime/star/rating/deal semantic families are not recolored by the new fallback, so authored dynamic colors remain intact.

The mature `ADStandalonePaintJS7104()` implementation remains byte-for-byte frozen.

## 2. “What’s it about?” body copy

The v7.473 main-frame capture proves the invisible body copy is real DOM text, not missing content:

- `#description-summary-card_primary-view .putb-main-text` at approximately 302×120 computes `rgb(0,0,0)`;
- its direct text `span` contains 182 characters and also computes black.

v7.474 owns exactly that description-summary text family and makes it white. The separate Product-details card treatment remains unchanged.

## 3. Selected Hardcover format cap

The selected `#media_format_1` card body already computes the accepted dark gray `rgb(48,51,53)` (`#303335`). Its `.swatch-title-text-container` alone computes `rgb(237,248,255)`, producing the light-blue top cap and a light-on-light risk while the text is already white.

v7.474 changes only the selected-state title cap to `#303335`, matching the lower half exactly, while retaining white text and existing Prime artwork. Unselected format cards are not broadened.

No MutationObserver, interval, requestAnimationFrame loop, Web scroll listener, polling loop, or recurring DOM scan is added. FULL, VIEWPORT and TRANSITION probe identities are regenerated as v7.474.

# AmazonDark v7.474 validation — visible copy + selected format state

## Direct device evidence used

Source base: **v7.473~standalone-survivor-sheet**.

Current capture reviewed: `AmazonDark-v7.473-ui-viewport-probe-20260924-002420-079-r1.tar` plus the supplied screenshot.

### Top standalone/offsite card

The v7.473 child frame proves the survivor implementation is active:

- `frameMeta.survivor7473 = 1`
- `standalone7104 = 1`
- two adopted stylesheets are present, including the v7.473 survivor sheet
- `brand-name` and `product-description` now compute white
- Sponsored computes the intended subdued gray

The exact current creative does **not** expose a second visible price/rating row: the visible child text inventory is brand, product description and Sponsored only. This means there is no hidden second row in this specific creative for v7.474 to reveal.

However, the historical v7.463 offsite capture of the same renderer family proves alternate creatives do expose a secondary row with:

- `[data-testid=formatted-price]`
- `#symbolOne`
- `#price-integer`
- `#price-fraction`
- `[data-testid=ratings]` and star SVGs

v7.474 extends the existing hydration-surviving survivor sheet to own those exact neutral price leaves plus inline-authored neutral black text (`rgb(0,0,0)`, Amazon `rgb(15,17,17)`, `rgb(0,0,17)`, and `#000`). The Sponsored rule remains later in the cascade. No Prime/star/rating/deal selector is added by this fallback.

### “What’s it about?”

The current main-frame capture proves the missing body copy exists and is painted black:

- `#description-summary-card_primary-view .putb-main-text`: approximately 302.4×120, computed `rgb(0,0,0)`
- its direct text span contains 182 characters and also computes black

v7.474 makes exactly this description-summary body family white.

### Selected Hardcover cap

The current capture proves:

- selected `#media_format_1` card body: `rgb(48,51,53)` (`#303335`)
- `.swatch-title-text-container`: `rgb(237,248,255)` with a 134×32 light-blue selected cap
- title text already has white text fill

v7.474 owns only `.a-button-selected .swatch-title-text-container` under `#inline-twister-scroller` and sets it to `#303335`, matching the lower card body while retaining white text and Prime artwork.

## Production architecture

`ADStandalonePaintJS7104()` remains byte-for-byte frozen.

SHA-256 of that source region:

`2734e76915bf577d60b9a012b6fee226035582aab2a499ee1c40e3a3130f7ebe`

No new delivery path was introduced. The offsite extension stays in the already-working `ADPDPGridCarouselFix7454()` constructable/adopted stylesheet. The description and selected-format fixes stay in the existing main-frame `ADPDPProbeBackedFixesJS7458()` style.

Production recurring-mechanism textual counts are unchanged from v7.473:

- `new MutationObserver(`: 0 → 0
- `setInterval(`: 0 → 0
- `requestAnimationFrame(`: 0 → 0
- Web `addEventListener('scroll'`: 0 → 0
- `createTreeWalker(`: 0 → 0
- `querySelectorAll(`: 1 → 1

Final `src/Tweak.xm`: **853,602 bytes**, below the frozen **856,000-byte** gate by **2,398 bytes**.

## Regression validation

The repository's exact v7.460→current normalization used by `scripts/validate.sh` was applied to a temporary in-repo regression tree. All **151/151** Python regression files passed in four bounded batches:

- batch 1: 40/40
- batch 2: 40/40
- batch 3: 40/40
- batch 4: 31/31

Focused current checks also passed directly from the source tree:

- `test_v7474_visible_copy_swatch.py`
- `test_v7473_standalone_survivor_sheet.py`
- `test_v7472_pdp_standalone_unification.py`
- `test_v7470_pdp_isolated_frame_ownership.py`
- `test_v7467_strict_pdp_contract.py`
- `test_v7464_pdp_ad_book_polish.py`
- `scripts/lint-logos.sh`
- shell syntax for `ui-probe.sh`, `skeleton-probe.sh`, and `validate.sh`

A sequential local invocation of the full strict wrapper exceeded the artifact runner's command window; this was not a regression failure. The complete normalized Python corpus above was therefore executed in bounded parallel batches, with zero failures.

`git diff --no-index --check` reports no whitespace errors.

## Expected device acceptance

After installing v7.474:

1. Top standalone/offsite creatives that include price/subcopy variants should show neutral black copy as white while Sponsored/dynamic semantic colors remain authored.
2. The “What’s it about?” descriptive body copy should be visible white.
3. The selected Hardcover title cap should be the same `#303335` gray as the lower half, with its text white and Prime unchanged.

# AmazonDark v7.608 — reviews filter menu buttons

Parent: complete v7.607 codebase.

## What changed

Adds one narrowly scoped CSS-only injector: `src/ADReviewFilterMenu7608.js` plus its gnu++98-safe include, appended after `ADPDPLastMile7607.js.inc` in `src/Tweak.xm`.

The supplied v7.605 FULL probe identifies the exact review filter secondary-view popover rooted at:

- `#a-popover-1.a-popover.a-popover-secondary.a-declarative:has(#reviews-filter-options-view)`
- `#reviews-filter-options-clear`
- `#reviews-filter-options-apply`
- filter option owners such as `#reviews-media-checkbox`, `#reviews-format-checkbox`, `#reviews-avp-checkbox`, `#cm_cr_marp_incentivized_filter_settings`, and `#star-filter-select`

Scoped fixes:

1. **Clear All button** → medium gray fill `#303335`, gray border `#747a7c`, white text.
2. **Apply button** → OLED black fill, gray border `#747a7c`, white text.
3. **Filter option button/card owners** → OLED black fills with recolored gray borders/dividers.
4. **Neutral text inside this menu** → white, with no changes to the existing checkbox/radio sprites, selected blue check, or geometry.

## Guardrails

- No new DOM scans, no MutationObservers, no timers, no RAF, no polling.
- No geometry edits: no border-radius, no width/height, no transforms.
- No image/sprite filtering: existing review menu sprites remain authored.
- All prior v7.607 PDP count/divider fixes remain intact.

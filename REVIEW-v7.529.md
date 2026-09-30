# AmazonDark v7.529 review

## Probe evidence
The v7.528 FULL capture confirms the v7.527/528 work fixed the main Interests and product-card floors, selected blue interest ring, heart row, hearts, badge floor, ATC styling and product-image taming. It also exposes the remaining prompt box as `_bW9ia_prompt-box_3ENUV` with an rgba-white floor.

The deeper v7.526 FULL sweep exposes the exact descendants that the shorter v7.528 sweep did not enumerate:
- plus raster: `img._bW9ia_add-icon_21zQ9` (33x33 raster, so CSS `color/fill/stroke` cannot recolor it)
- contextual menu button: `#intp-contextual-menu-inline._bW9ia_more-icon-btn_6YH2k._bW9ia_more-icon-btn-inline_1pFBK`
- three-dot raster: `img._bW9ia_more-icon_1Qpwd`
- product title owner: `.s-title-instructions-style h2.a-color-base.s-line-clamp-2.a-text-normal`
- neutral metadata: `.s-title-instructions-style .a-row.a-color-base` / `.a-size-mini.a-color-secondary`
- price owner: `.s-price-instructions-style`

## v7.529 changes
- OLED prompt/action-bar box while leaving its existing blue border color untouched.
- OLED contextual menu button + 1px gray circular ring.
- White three-dot raster via exact brightness/invert treatment.
- White large plus raster via exact brightness/invert treatment; gray outer ring remains unchanged.
- White product title and exact neutral metadata owners.
- White `.a-price` family under the exact Interests price owner.
- No broad recolor of stars, discounts, deals, savings, selected blue ring or other dynamic-color families.

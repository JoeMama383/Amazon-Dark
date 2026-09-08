# AmazonDark v7.363 audit

## Baseline

Parent: `v7.362~universal-dual-ui-probes`.

The change is intentionally narrow. Launch/splash behavior, native theming, TWB architecture outside the exact autocomplete thumbnail lane, ad ownership, Cart skeleton recorder, and the v7.362 universal dual-probe architecture are not redesigned.

## Probe-backed findings

1. The apparent missing magnifiers in two autocomplete rows are not missing search glyphs. The full probe shows loaded `img.s-suggestion-image-left` product thumbnails in rows 5 and 9. Their image/background owners were being caught by the generic `[class*=suggestion]` floor rule.
2. The `Ask Alexa about this` row contains an authored `i.s-suggestion-rufus-autocomplete-bh-mshop-icon`. The generic `[class*=autocomplete]` floor used the `background` shorthand and therefore cleared its authored background artwork.
3. Product Search Related Searches uses `textref-border textref-box-onlychild` card owners. They retained stock white floors and light borders; the search glyph is `i.a-icon-search.textref-icon-opacity`.
4. The Cart claimed Apex coupon is a separate `div.apex-coupon-tile.claimed.red` state. It no longer sits under the wrapper the earlier rule depended on. Its SVG contains `path.apex-coupon-icon-background` plus a separate white check path.
5. Cart savings pills use `.sc-unified-promotion-message-badge`, with the captured lime background `rgb(127,218,105)`.

## Fixes

- Narrow the generic autocomplete/suggestion floor selector with `:not([class*=icon])`, `:not([class*=glyph])`, and `:not([class*=image])` where appropriate.
- Explicitly keep suggestion thumbnail image containers/shields transparent and keep `img.s-suggestion-image-left` visible.
- Add the exact thumbnail leaf to the existing autocomplete TWB lane.
- Preserve Rufus/Alexa authored artwork with transparent background-color only; no custom replacement image is introduced.
- Theme exact `textref` Related Searches cards to OLED black + `#494d4d` + white copy/search icon.
- Anchor Apex coupon styling to `.apex-coupon-tile-container.apex-coupon-tile-mobile`, which survives both states.
- Claimed Apex SVG: black `apex-coupon-icon-background`, white non-background path.
- Change Cart unified-promotion badge to `#5a9e43` with OLED-black text; use doubled `#sc-page-container` specificity so the exact badge copy beats the generic Cart white-text rule.

## Validation

- All existing Python regression scripts execute successfully.
- Added `tests/test_v7363_search_related_cart_claimed.py` for exact ownership and no-recurring-work assertions.
- Local Chromium harness executes the actual concatenated `ADFloorJS` + `ADTWBJS` payloads and verifies:
  - v7.362 autocomplete shield/icon artwork failure reproduces; v7.363 thumbnail shield is transparent, thumbnail remains visible at TWB strength, and Rufus artwork survives.
  - v7.362 Related Searches card remains white; v7.363 is `rgb(0,0,0)` with `rgb(73,77,77)` border and white icon/copy.
  - v7.362 claimed coupon remains `rgb(255,227,227)`; v7.363 becomes `rgb(0,128,0)`, with black circle and white check.
  - promotion badge becomes `rgb(90,158,67)` and its copy computes to black.

## Build note

This environment does not contain Theos or an iOS SDK, so no local `.deb` compile is claimed. The repository's existing macOS GitHub Actions workflow remains unchanged and is the authoritative rootless package build after push.

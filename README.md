# AmazonDark v7.124 — Search interface

Built on v7.123. Two fixes, both read directly out of the v7.123 search probe.

## 1. The grey and white squares

The probe named the glyphs and their computed values:

    icon-past-search-suggestion   bg=rgb(157,163,163)   mask=none
    icon-close                    bg=rgb(232,230,227)   mask=none
    icon-search-suggestion        bg=rgb(0,0,0)         mask=none

The rules setting those carried the comment *"background-color is mask ink"*. That is
only true when a `mask-image` is present to clip it. **`mask` is `none` on all three** —
so `background-color` was not ink, it filled the entire 20x20 box. That is exactly the
grey squares on the left and white squares on the right of your screenshot. The
magnifier rows looked fine only because their `rgb(0,0,0)` box matched the OLED floor.

v6.0.185 had this right and said so in its own comment — *"the mask is the shape; the
visible colour is the element background-color"* — and it gated that on
`if (mi && mi !== 'none')`, checking a mask was actually there. Icon-font glyphs draw a
character from `::before`, where `color` is the ink and `background-color` only paints a
block behind it.

Now: `background-color: transparent` plus `color` ink on all three families and their
pseudo-elements, with `background-color` reinstated **only** for a genuinely masked
leaf, declared afterwards so it wins where it applies.

Section headers and row copy also take light ink — the probe reports the autocomplete
body at `color: rgb(15,17,17)` on an `rgb(0,0,0)` floor, which is why YOU MAY BE
INTERESTED and RECENT were nearly invisible.

## 2. White planes behind Search

Three views were `rgba(1,1,1,1)`:

    UILayoutContainerView (0,103 430x829)
    UIView                (0,0   430x932)
    UIView                (0,103 430x829)

`ADNativeFloorCandidate` only claims React cards, so nothing owned these. A narrow
structural-plane owner now claims them: opaque, luminance above 0.90, at least 95% of
window width and 55% of height, and no layer contents. Claimed at both
`didMoveToWindow` and `setBackgroundColor:` so a later white assignment cannot undo it.

## Not in this build: the keyboard

The keyboard is `UIKeyboard` / `UIKBBackdropView`, outside the webview and outside these
hooks. Making it OLED is a real change with real regression risk to key legibility, and
it deserves its own build rather than being bundled into a search fix.

## Verification

- Glyph rules rebuilt in a real engine from the probe's markup: no filled box on any of
  the three families, correct ink on each, a genuinely masked leaf still gets background
  ink, and header text is light. 7/7.
- Plane predicate modelled against the probe's exact geometry: all three white views
  claimed; window, black nav bar, small white card, short white banner, image host,
  translucent overlay and the search pill all correctly skipped. 10/10.
- Declared-before-use audit clean; balance 0/0/0; `scripts/lint-logos.sh`.

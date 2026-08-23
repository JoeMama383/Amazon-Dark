# AmazonDark v7.0.26

Home floor/chrome exclusion correction built on v7.0.25.

- The complex top hero and the first ordinary card row can both live in `#gwm-Deck`.
- v7.0.26 restores OLED only to known ordinary card-shell roots in that deck and excludes roots carrying complex creative/video/theming background markers.
- The below-fold `#gwm-Deck-btf` and legacy `#gwm-PageContent` card-shell ownership remain.

Percent-off/deal chrome:
- Generic structural descendant floor painting is removed.
- v7.0.25's badge/deal replacement paint is removed.
- Amazon's own `% off`, Limited time deal, coupon, discount, badge, chip and pill descendants are simply left alone.

Sponsored chrome:
- Sponsored/ad-feedback text is removed from the generic secondary-text repaint.
- `adFeedbackMainComponent` is removed from generic transparent/box-shadow cleanup.
- No custom Sponsored glyph is drawn; the stock text/glyph host remains Amazon-owned.

Preserved:
- OLED card-shell floors.
- inherited light card copy;
- product-media `mix-blend-mode:normal` fix;
- TWB brightness filters;
- v7.0.25 bottom-nav behavior;
- zero new MutationObserver, Home runtime scan, scroll listener, timer, interval or RAF loop.

# AmazonDark v7.0.22 — Home floors and bottom nav go OLED

Both fixes come from the v7.0.20 probe, not from inference.

## Web: the card rules were scoped to an element that does not exist

Every Home card rule was written as `#gwm-PageContent [class*=…]`. The probe's parent
chains are:

    gwm-Deck-btf > gwm-Deck > a-page > BODY

There is no `#gwm-PageContent` on Home, so **all 27 of those selectors matched nothing**.
That is why the surfaces the probe measured stayed light:

    .a-cardui                                 rgb(255,255,255)
    _cXVhZ_mosaic-card_1C-_R                  rgb(255,255,255)
    _hp-mosaic-container_style_container__    rgb(255,255,255)
    _cXVhZ_asin-container_EaHh8               rgb(247,247,247)
    p13n-uf                                   rgb(247,247,247)

All 27 are rescoped to `:is(#gwm-PageContent,#gwm-Deck,#a-page)`, and the floors above
are named explicitly — several had no rule at all.

**Build-hash pins removed.** Two selectors were written `[class*=cXVhZ][class*=…]`.
`_cXVhZ_` is a per-deploy Amazon bundle hash; pinning to it means the rules die the next
time Amazon ships. They now match the stable part of the class name only.

## Native: the bottom bar had no owner

The probe measured `ANXTabBarView` at `(0.0,850.0 430.0x82.0)` with view and layer both
`1.000,1.000,1.000/1.000`, and its sibling `UIView` backing at the identical rect also
white. Only `ANXTopNavBackgroundView` was hooked — nothing claimed the bottom bar, which
is why it stayed white against an otherwise OLED window (`AppCXWindow` and
`UILayoutContainerView` both measured `0.000,0.000,0.000`).

`ANXTabBarView` now has an assignment-time owner in the same shape as the top nav:
`setBackgroundColor:`, `didMoveToWindow`, `layoutSubviews`. Three exact entry points, no
observer, no scan, no timer. The backing view is claimed too, since the probe shows the
white covers it and not just the bar.

## Verification

- Selectors tested against a rebuild of the probe's actual chain: the old scope matched
  nothing (reproducing the bug), the new scope matches all five measured floors, media
  is still excluded, and the hash-agnostic form matches the `_cXVhZ_` classes without
  naming the hash. 8/8.
- `scripts/lint-logos.sh` caught `%orig(ADOLED())` — a nested call in `%orig`'s
  arguments. Resolved to a local first, matching the existing top-nav owner.
- Balance 0/0/0.

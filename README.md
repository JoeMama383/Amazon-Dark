# AmazonDark v7.479 — timer/action-bar + Returns theming pass

This is the same v7.479 package line, extended with the probe-backed Returns / label-instructions surfaces supplied after the first v7.479 handoff. The prior Home and PDP repairs remain intact.

## Existing v7.479 residual fixes

- The three TNF countdown numeric chips keep the exact `atf-countdownCard-Text-Timer-Numeric-*` owner and receive independent OLED paint behind white numerals.
- `RCTView#AXFActionBarContainer` has its top React border cleared while the child Add-to-Cart button keeps its separate 1 pt gray ring.

## Return Instructions main page — FULL r1

The supplied FULL capture exposes the exact web families rather than requiring a broad page walker in production:

- `#print-label-button-app` is the yellow primary button. It is now OLED black with white text and the standard gray button border.
- `#share-label-secondary-view-trigger > a.a-touch-link.a-box` is the white “Email copy of label” row. Its floor is OLED, copy is white, edge is gray, and its neutral chevron is made visible.
- `#return-deadline-display .a-alert-info` is the white deadline box. Only its floor/copy are dark-themed; its authored blue alert ring is deliberately left untouched.
- the `printable-section` table/row family is made OLED with gray dividers/borders and white neutral copy.
- neutral headings and list/body copy are made white; anchor/link colors remain authored via `currentColor`.
- screen-only content images are tamed with the existing dark-raster treatment. The rules are wrapped in `@media screen` so printing is not recolored.
- hidden success/error alert families receive OLED floors while their authored semantic border/icon colors are preserved.

## Email-copy secondary view — FULL r2/r3

The collapsed and expanded captures identify `#share-label-popover-input-section`, `#email-recipient-selection`, and `#button-share` directly.

- the white full-screen Amazon popover shell becomes OLED black;
- accordion cards/rows/inner panes become OLED with gray borders and white neutral copy;
- the email text area gets a dark control fill, white copy/caret, and gray wrapper border;
- the Share button becomes OLED with white text and the standard gray button border;
- checkbox/symbol artwork is not recolored, preserving authored state colors;
- links remain their authored dynamic colors.

## Bottom gradient fade — FULL r1

The FULL native snapshot identifies a 430×82 near-white `UIView` beside `ANXTabBarView` with a `CAGradientLayer`. The native repair only suppresses that exact near-full-width, 40–110 pt, gradient-bearing bottom-bar sibling. It does not hide arbitrary views and adds no recurring hierarchy scan.

## Performance contract

All Returns web work is declarative CSS installed at document start. There is no MutationObserver, polling, timer, RAF loop, or scroll listener. The native fade repair runs only from the existing bottom-tab-bar mount/layout ownership path.

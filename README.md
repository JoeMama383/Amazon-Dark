# AmazonDark v7.0.32

Targeted Home heading correction built directly on v7.0.31.

## Home heading gap
v7.0.31 fixed many Home card/mosaic text families, but some section headers are plain
`H1`-`H6` nodes directly under below-fold Home widget wrappers. They have no matching
Amazon heading/title class, so they can keep the stock dark ink even though their floor
is OLED black.

v7.0.32 adds one document-start CSS rule for heading tags inside `#gwm-Deck-btf` and
`.gwm-dashboard-container`. This covers section/card headers such as the remaining dark
Home headings without adding a scan or runtime classifier.

The rule explicitly excludes:
- Sponsored/ad-feedback ancestry;
- deal/badge/coupon ancestry;
- hero/single-creative/single-video/theming/creative/ad/canvas-card ancestry.

Amazon therefore continues to own hero campaign text and all Sponsored text/glyphs.

## Preserved architecture
TWB remains the v7.0.31 single-owner design. No MutationObserver, querySelectorAll,
TreeWalker, scroll listener, interval, RAF loop, or recurring scanner is added.

The standalone APE shell remains on the existing narrow transparent placement-chrome
rule. No unproven inner-frame standalone-ad painter is added in this build.

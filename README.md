# AmazonDark v7.0.33

Direct production rebase on **v7.0.29**.

## Scope
This release intentionally keeps the v7.0.29 hero isolation, Sponsored isolation, OLED floors, TWB behavior, native hooks, 120 Hz/JIT, bottom navigation, and SpringBoard launch code unchanged.

The only functional correction is **Home ad/card text ink**:

- ordinary below-fold card and mosaic headers/captions are light again;
- bare Home section H1-H6 headings are light again;
- seasonal/widget headline, header-link, and caption families are light again.

Sponsored/ad-feedback text and glyphs remain Amazon-owned. Deal/badge/coupon content remains excluded. Hero/single-creative/single-video/theming/creative/ad/canvas card descendants remain excluded from the bare-heading rule, preserving v7.0.29 campaign contrast.

## Performance
The correction is document-start CSS only. It adds no MutationObserver, querySelectorAll, TreeWalker, scroll listener, interval, requestAnimationFrame, timer, DOM scanner, or media census.

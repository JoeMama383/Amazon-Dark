# AmazonDark v7.0.31

Single-owner TWB correction built directly on v7.0.30.

## Hero correction
v7.0.30 could tame one hero through several independent owners at once:
- the actual IMG/VIDEO/CANVAS;
- a known background leaf;
- the entire `single-creative` / `single-video` / `theming-card` root;
- a nearby-background ancestor marker;
- the bounded hero background pass.

That stacked darkening is removed.

v7.0.31 follows the donor boundary:
- IMG is tamed as IMG;
- VIDEO/CANVAS is tamed as media;
- `single-creative-card-background`, `single-video-card-background`,
  `theming-card-background`, and `vjs-poster` are background-only owners;
- classless hero background URL/pseudo-image recovery remains bounded to 140 visible
  child-frame candidates;
- no whole hero/card root receives a TWB shadow;
- no luminance-based pure-color hero container is dynamically darkened;
- no media event walks ancestors and adds additional background tame layers.

This keeps the hero coverage without stacking TWB over Amazon's live text/chrome.

## Home text correction
OLED Home cards/mosaics now get scoped light text ownership for normal card copy,
headings, header links and captions.

Excluded from that light-text owner:
- Sponsored/ad-feedback text/glyph ancestry;
- badge/deal/coupon chrome;
- hero/creative trees.

## Sponsored isolation
Sponsored/ad-feedback ancestry is excluded from:
- universal IMG TWB;
- seasonal SVG TWB;
- child media classification;
- hero background/pseudo-image recovery.

Amazon still owns Sponsored text and glyph color/artwork. No replacement Sponsor color
or glyph is added.

## TWB coverage
v6.0.200's cheap universal ordinary-IMG coverage model is used: all normal IMG media is
tamed declaratively, with identity/UI/Sponsored exclusions.

The bounded runtime is retained only where CSS cannot express the donor behavior:
- standalone child-frame full-raster IMG skip;
- VIDEO/CANVAS classification;
- hero CSS-background / pseudo-image recovery.

No MutationObserver, querySelectorAll, TreeWalker, scroll listener, interval, RAF loop,
or recurring scanner is present.

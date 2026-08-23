# AmazonDark v7.0.38

Production build rebased directly on v7.0.33 (the v7.0.29 baseline plus the proven Home ink correction).

## Probe-driven fixes

### Home multi-category cards
The v7.0.37 current-frame probe identified the bright Pet wellness-style grid as:
- `a-cardui`
- `_multi-category-card_style_gwm-multiCategoryCard_*`
- direct `<img class="_multi-category-card_image_*">` leaves

Those IMG leaves were outside v7.0.33's TWB selector map. v7.0.38 adds a direct static selector for them.

The same media leaf also gets `mix-blend-mode: normal` on the OLED Home floor. This is intentionally leaf-only and is aimed at the Disney-style disappearing-image failure where the visual can appear during the long-press interaction but vanish again against the black card floor.

### Hero / creative isolation at any Home depth
v7.0.33's card-local Home text rule assumed hero/creative cards lived outside `#gwm-Deck-btf`.
Amazon can now insert hero/standalone creative cards farther down Home.

The text owner now rejects hero, single-creative, single-video, theming, creative-card,
ad-card, canvas-card, mobile-mshop-ad and APE ancestry regardless of vertical position.
Amazon therefore keeps ownership of campaign text/background contrast.

### Standalone / child-frame TWB
TWB remains media-only.
A child document gets one documentStart attribute and static CSS tames raster `<img>` leaves
with identity/UI/Sponsored exclusions. No frame walk or media census is used.

If a standalone Home ad renders direct IMG/VIDEO/CANVAS media in its known
mobile-mshop/APE wrapper, that media is also tamed directly. Sponsored feedback text and glyph
ancestry is excluded.

## Performance
No MutationObserver.
No querySelectorAll.
No TreeWalker.
No scroll listener.
No setInterval.
No requestAnimationFrame.
No media sweep.
No recurring timer.
No viewport scan.
No getComputedStyle loop.

The only new runtime operation is one `window.top !== window` check per document at documentStart;
all actual coverage is static CSS.

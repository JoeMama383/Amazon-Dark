# AmazonDark v7.0.30

Production build based directly on v7.0.29.

## TWB strategy
This build stops trying to enumerate only the currently-visible v7 selectors. Instead it ports the *coverage contract* of the v6.0.185 lineage onto the lightweight v7 runtime. The scan-heavy v185 scheduling is not ported.

Coverage retained semantically:
- ordinary product/search/PDP media;
- generic large Home/category imagery;
- Home single-creative, single-video, video-card, theming-card, canvas, VJS, APE, hybrid-sponsored, NPACK/GWM/mosaic/p13n creative families;
- hero/ad-frame IMG/VIDEO/CANVAS, CSS-background and pseudo-image leaves;
- standalone/compact sponsored product media with the v185 full-raster guard for static images;
- forced product sections such as Subscribe & Save, Keep Shopping, Shop previously watched, Returns, gift cards, Alexa for Shopping, Lists & Registries, Buy Again and Your Interests;
- review/customer-photo media;
- seasonal mosaic IMG/SVG artwork. Sponsored/ad-feedback descendants remain excluded.

Performance architecture:
- no MutationObserver;
- no querySelectorAll;
- no TreeWalker;
- no scroll listener/recovery;
- no interval or RAF;
- one bounded initial media-only pass (max 420 IMG/VIDEO/CANVAS nodes);
- dynamic media is handled only by media lifecycle events;
- hero CSS-background recovery is bounded to 140 visible nodes and only inside hero-sized child frames.

## Text regression correction
The v7.0.29 `#gwm-Deck *` foreground exclusion was too broad and covered ordinary Home content beneath the hero. It is removed. Only actual hero/creative/theming/video/canvas/ad-card ancestry is excluded from the generic light-text owner.

## Sponsored isolation
Sponsored/ad-feedback text and info glyphs remain Amazon-owned. Seasonal SVG TWB now explicitly excludes Sponsored/ad-feedback descendants so TWB cannot create a text-vs-glyph brightness mismatch.

## Native TWB
Native UIImageView ownership remains assignment/mount/layout-only. The v185 Person/Alexa section coverage is represented with bounded local semantic checks instead of historical scroll/window scans. The black overlay is inserted beneath child sublayers so labels/glyphs hosted inside an image view remain visible.

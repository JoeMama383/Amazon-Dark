# AmazonDark v7.0.29

Production correction built directly from v7.0.28.

## Sponsored text/glyph isolation
The text-vs-glyph mismatch was not fixed by taking ownership of Sponsored ink. Instead, v7.0.29 removes two ways AmazonDark could still feed a different inherited `color` into the stock feedback glyph while Amazon's text leaf kept its own inline color:

- root/page/card floor rules no longer set inherited foreground color;
- generic primary/secondary text rules exclude Sponsored/ad-feedback ancestry, not only the exact label leaf.

There is still no Sponsored-specific replacement text color, sprite, SVG, mask, filter, pseudo-element, opacity, geometry or fallback glyph rule.

## Hero isolation
The top Home hero/creative tree is now fully excluded from generic foreground ownership.

A separate bug was also removed: v7.0.28's media-protection rule forced `background-color:transparent` onto hero/single-creative/theming-card/ad-card containers. That could erase Amazon's campaign floor while generic text stayed light, producing the pale-background/bright-text contrast visible in the screenshot.

v7.0.29 only clears background color on true media/product-image wrappers. Hero/creative/theming/ad-card containers keep Amazon's own floor and text palette.

## TWB Home restoration
The current 7.x TWB sheet had become too narrow. v7.0.29 restores cheap document-start CSS coverage for previously proven families:

- ordinary/product imagery;
- `a-amazon-image` product leaves under the normal Home dashboard/below-fold cards;
- seasonal `hp-mosaic` / widget IMG and SVG artwork;
- Home single-creative / single-video imagery;
- canvas-card media and VJS video;
- theming-card / VJS poster CSS-background artwork using a background-only inset shade.

This does not add a DOM walker, MutationObserver, load listener, selector scan, scroll recovery, interval or RAF loop.

## Remaining diagnostic boundary
This build intentionally does not add a broad all-iframe/all-image TWB rule. If an individual cross-origin ad-frame photo still escapes after v7.0.29, that remaining renderer should be probed rather than solved by globally filtering every image in every ad frame.

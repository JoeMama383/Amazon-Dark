# AmazonDark v7.559 audit — order-item detail

The supplied FULL archive completed successfully and captured the exact order-item page rather than Account. The main WebKit document is 430x1542 and the relevant visible owners are probe-backed:

- `section#pop.layout__background` — stock light-gray page structural background;
- `.pop-card` — stock white section/card floors (the visible order cards are `.js-pop-card`);
- `a.a-touch-link.a-box` — stock white 402x52 action rows with 1px light dividers;
- `i.a-icon.a-icon-touch-link` — 14.1x14.1 border-painted chevrons;
- `.item-view__qty-large` — 30x30 absolute quantity badge, 15px radius, 1px `rgb(204,204,204)` border, translucent white fill, dark text, 17.6px font and 30px stock line-height;
- `.item-view__inner-col > a.a-link-normal > img` — product image; the separate `.connection-share-icon` remains excluded.

v7.559 adds one document-start declarative style owner gated by the exact captured quantity-badge family. It makes structural cards OLED, text/dividers follow the established algorithm, preserves dynamic colors, tames the exact product raster, and uses flexbox only inside the quantity badge to center the numeral. It deliberately does not alter the badge's authored outer geometry.

Regression verification: the final source passed all 213 normalized repository regression tests, including the historical core-hash, performance-consolidation, strict PDP, and v7.558 Filters/probe/no-Account-paint contracts. Logos lint and shell syntax checks also pass.

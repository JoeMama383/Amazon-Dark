# v7.523 review

Base source: **v7.522~returns-label-centering**.

## Probe-backed root cause

The supplied v7.522 FULL r2 capture is complete: the dedicated Person walk advances through seven offsets to 2321.3 pt, restores offset 0, and reports `PERSON_FULL_SCAN_END reason=bottom`. The Returns card itself is still `RCTView#yr_item_0`, 292×69.3 pt, with React `borderWidth=1.00` and `borderRadius=12.00`; no card-geometry regression is present.

The missing left arcs come from a different descendant. Inside `yr_item_0`, a 60×67.3 pt reserved-thumbnail wrapper begins one point inside the card. Its paint-only child fills that wrapper exactly, has no subviews, and is opaque OLED with layer contents. Because the card does not clip children and React's authored border is rasterized on the parent, that child covers the parent border where the radius curves inward at the top-left and bottom-left. It does not cover the straight middle portion of the left edge, matching the screenshot. Press-time React updates can redraw the parent above that child temporarily, which explains why the full contour can appear while pressed.

## v7.523 correction

`ADPersonReturnsLeftCornerOccluder7523` identifies only the paint-only child that:

- is an `RCTView` under an exact `yr_item_N` card;
- has no subviews;
- fills its immediate thumbnail wrapper; and
- lands within the narrow left 48–72 pt column while spanning the card interior height from approximately (1,1).

That exact plane is forced transparent through the existing guarded background writer. It is reasserted from the normal `RCTView` `didMoveToWindow`, `didMoveToSuperview`, and `layoutSubviews` ownership path, from the bounded Returns section priming pass, and from the existing React `setBackgroundColor:` interception. This covers initial mount, submenu/back re-entry, refresh, and offline/online React rehydration without any observer, timer, polling loop, recurring hierarchy scan, or new production traversal.

The v7.522 text-centering function is unchanged. Amazon's Returns card frame, bounds, transform, mask, border width, per-edge widths, border radius, and carousel spacing remain untouched.

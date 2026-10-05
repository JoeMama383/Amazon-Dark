# v7.566 validation

Baseline: origin/main 1737a658, user-pushed v7.565.
Evidence: v7.565 FULL 20261005-134015-635-r1 and IMG_7503/7505; prior v7.564 Health VIEWPORT 082928-544 establishes the 384x96 Ask Health AI raster.

The map pin reports transparent background but an inset rgba(0,0,0,0.58) 9999px shadow. Its ancestry matches the generic canvas-container background-art rule. A scoped ID selector clears this shadow while retaining background-image and transform. The entire map container owns brightness; canvas/images do not add a second filter. The Health raster no longer receives the explicit v7.565 native TWB overlay.

Tests cover captured floor/control/glyph selectors, preserved green/blue semantic copy, pin-shadow removal, emitted map JavaScript at disabled/strength bounds, and Health overlay exclusion with other media taming retained. The existing compiler fixture includes the new map helper dependency. CSS matcher dependencies are installed in CI. No runtime observers, timers, scrolling listeners, or recurring DOM walks were added.

Native Theos package build and phone rendering checks remain pending.

Local result: lint-logos OK; strict regressions OK (219), including Clang Objective-C++ preflights and CSS cascade tests.

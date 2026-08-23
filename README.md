# AmazonDark v7.0.45

Production build on the v7.0.44 static-CSS architecture.

## Changes

- Completes the College/seasonal Home chevron owner by whitening the exact `i.a-icon.a-icon-dropdown` sprite leaf anywhere inside the Home deck, while retaining the narrower seasonal/MAB fallbacks.
- Converts the probe-confirmed NPACK `_asin-container-white__` product-photo shell from white/gray to OLED black. The product raster remains independently TWB-filtered, producing the same black contain/padding plate seen in the v6.0.185 reference instead of shading the white shell to gray.
- Makes `SBSearchField` and `ANPSearchBarRightButton` use the same dark neutral fill (`#303335`) and light foreground ink. Both surfaces are reasserted only through their exact lifecycle/setter hooks so Amazon cannot restore the lighter fill later.
- Keeps the v7.0.44 seasonal background-video TWB persistence fix unchanged.

## Performance

Home/hero changes remain document-start CSS only: no MutationObserver, querySelectorAll, TreeWalker, scroll listener, interval, requestAnimationFrame, or recurring repair loop. Search/location are native UIKit surfaces, so they use direct class hooks already in the tweak rather than DOM work or hierarchy scanning.

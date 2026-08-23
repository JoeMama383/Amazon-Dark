# AmazonDark v7.0.46~probe

Probe build on the exact v7.0.45 production base.

## Production changes

- Ports the cheap v6.0.185 Web border-color contract for stable Amazon card/container families. Existing border widths, radii, shadows and layout remain Amazon-owned; only visible border/outline color is forced to v6.0.185 final gray `#3b4043`. Seasonal/mosaic nested structural shells receive the same gray so Amazon white borders cannot survive on the inner border-bearing node.
- Adds a cheap standalone-ad child-frame theme. A one-time documentStart referrer gate marks non-PDP/non-Search child frames, and a CSS media query limits the dark treatment to short/wide standalone creatives. The frame floor becomes OLED black and ordinary ad text becomes `#e8e6e3`; images, layout, Sponsored row/glyphs and interaction remain unchanged. No DOM scan, observer, timer or scroll repair is added.

## Palette probe

- Manual `SIGUSR2` trigger only.
- Appends one current-page frequency snapshot to `AmazonDark-palette-probe-7046.txt` in Amazon's Documents sandbox.
- Records distinct computed background, text and border/outline colors with occurrence counts, visible viewport area for background colors, and one example selector per color.
- Intended captures: Home, Search, PDP and Cart.
- The probe is dormant until triggered and adds no MutationObserver, timer, RAF, scroll listener or normal-runtime DOM scan.

## Preserved

- v7.0.45 seasonal photo plates, College chevron and unified search/location fill.
- v7.0.44 NPACK background-video TWB persistence.
- Existing TWB, 120 Hz, JIT, launch cover, navigation behavior and all unrelated static theme rules.

## Previous v7.0.45 notes

# AmazonDark v7.0.45

Production build on the v7.0.44 static-CSS architecture.

## Changes

- Completes the College/seasonal Home chevron owner by whitening the exact `i.a-icon.a-icon-dropdown` sprite leaf anywhere inside the Home deck, while retaining the narrower seasonal/MAB fallbacks.
- Converts the probe-confirmed NPACK `_asin-container-white__` product-photo shell from white/gray to OLED black. The product raster remains independently TWB-filtered, producing the same black contain/padding plate seen in the v6.0.185 reference instead of shading the white shell to gray.
- Makes `SBSearchField` and `ANPSearchBarRightButton` use the same dark neutral fill (`#303335`) and light foreground ink. Both surfaces are reasserted only through their exact lifecycle/setter hooks so Amazon cannot restore the lighter fill later.
- Keeps the v7.0.44 seasonal background-video TWB persistence fix unchanged.

## Performance

Home/hero changes remain document-start CSS only: no MutationObserver, querySelectorAll, TreeWalker, scroll listener, interval, requestAnimationFrame, or recurring repair loop. Search/location are native UIKit surfaces, so they use direct class hooks already in the tweak rather than DOM work or hierarchy scanning.

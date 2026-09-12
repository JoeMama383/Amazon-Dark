# AmazonDark v7.414 audit — location navigation renderer fix

## Release
- Version: `7.414~location-navigation-renderer-fix`
- Runtime: `v7.414-location-navigation-renderer-fix`
- Direct parent: `7.413~address-location-compile-fix`

## Supplied evidence and root cause
The supplied v7.413 FULL/VIEWPORT/TRANSITION captures show the current Search location-navigation family under:
`AppCXWindow -> AppCXBottomSheet -> AppCXBottomSheetContentView -> SNPRootView -> ... -> WrappedNileFeatureContainer -> ... -> navigation-root`.

The live bottom-sheet `SNPRootView` is about 430x763 on a 430x932 screen (~81.9% screen height). Older location ownership requires the nearest `SNPRootView` to be >=85% of screen height and therefore rejects this current renderer. That explains why the previous v7.412/v7.413 auxiliary rules could be present in source yet still miss the actual screen.

### Enter a US zip code — FULL r1
- lower content scroll: ~394pt wide;
- header row: ~394x35.3 with 1pt bottom border;
- input: `RCTSinglelineTextInputView`, ~394x44, stock opaque white, 1pt React border, radius 3;
- Apply inner control: `RCTView`, ~394x45, stock Amazon yellow (`~0.941/0.757/0.294`), 1pt React border, radius 2;
- Apply/header neutral text is stock-dark.

### Choose your location — FULL r2 / VIEWPORT / transition
The three address cards are ~140x130 React views under `RNCEKVExternalKeyboardView` inside a horizontal `RCTScrollView`.
The settled probe can report the card UIView/model background as already black while the border-rendering layer still has `contents=1`. This matches the on-device failure where the card remains or flashes visually white even though a late background correction appears to have succeeded. The failure is therefore not just a missing `backgroundColor`; React's cached border/background raster must be invalidated and regenerated.

### Ship outside the US
The supplied screenshot shows the same location-navigation family with stock-white country rows, stock-dark row text/section headings and light separators. v7.414 applies the same structural root ownership to neutral country/list surfaces; it does not introduce a route-name or text-string runtime classifier.

## v7.414 correction
1. Marks only the exact AppCX bottom-sheet Nile location root using `AppCXBottomSheetContentView` plus `WrappedNileFeatureContainer` plus `navigation-root`. No final-height gate.
2. Performs one bounded <=640-node prime when that exact root becomes identifiable. There is no recurring scan.
3. Re-commits exact 140x130 address-card backgrounds through React's own `setBackgroundColor:` path, synchronizes the layer, removes only the background-color animation and invalidates both UIView and CALayer display. This forces React's cached `layer.contents` border/background raster to regenerate dark.
4. Neutral text in both React text renderer paths is made light at assignment plus final draw/layout. Saturated semantic colors remain authored.
5. ZIP input is standard dark-gray fill + gray React border + light text/placeholder.
6. Apply is OLED + gray React border + light text; no duplicate CALayer ring is added.
7. Neutral wide country/list rows and bright React surfaces become OLED. Thin separators and neutral border-bottom writes become standard AmazonDark gray.
8. Selected orange address borders and authored blue links survive because only neutral border colors are remapped. No image/SVG/sprite tint/filter was added.

## Architecture / performance
- New production MutationObserver: 0
- New setInterval: 0
- New requestAnimationFrame loop: 0
- New Web scroll listener: 0
- New polling loop: 0
- New recurring hierarchy scan: 0
- New WKUserScript family: 0
- New hook class: 0; existing React hooks are reused
- New traversal: one bounded <=640-node prime only when the exact location-navigation root is first marked

## Validation
- `scripts/lint-logos.sh`: PASS
- `sh -n scripts/ui-probe.sh`: PASS
- `sh -n scripts/skeleton-probe.sh`: PASS
- `sh -n layout/DEBIAN/postinst`: PASS
- `tests/test_v7414_location_navigation_renderer_fix.py`: PASS
- inherited v7.413 compile-fix regression: PASS
- inherited v7.412 address/location auxiliary regression: PASS
- 85/85 bounded Python regression files excluding exhaustive handoff: PASS
- exhaustive `tests/test_probe_handoff.py`: PASS
- strict `AD_STRICT_VALIDATE=1 sh scripts/validate.sh`: reached inherited regressions with no assertion failure before the environment 120-second execution ceiling
- diff whitespace check for `src/Tweak.xm`: PASS
- `layout/DEBIAN/postinst` mode: 0755

A local Theos/iOS SDK compile is not available in this environment. GitHub Actions/on-device Theos remains authoritative for arm64/arm64e compile/link/package validation.

## Device verification
- Reopen Choose Your Location repeatedly: all three cards must be OLED from the first visible frame and never lock white; names/addresses stay light; selected orange border and blue links remain authored.
- Open Enter a US zip code: input gray/gray/light, Apply OLED/gray/light, header light, separator gray, chevron preserved.
- Open Ship outside the US: rows OLED, ordinary text and headers light, dividers gray, chevron preserved.

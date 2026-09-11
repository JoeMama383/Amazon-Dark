# AmazonDark v7.407 audit — Product Search → PDP transition skeleton

## Base
- Direct parent: `7.406~video-sponsored-footer-restore`.
- All v7.406 PDP, Product Search, video-border and Sponsored-footer behavior is retained.

## Probe-backed diagnosis
The v7.406 transition capture for Product Search → PDP records the incoming native hierarchy before the PDP WebUI is ready. The surrounding `AWLoadingIndicatorFullScreenModalBar`, incoming `AMIWebViewController` root, and WKWebView are already OLED black. The remaining light painter is an exact full-screen `IESSkeletonView` (`430×810.5`) under `AWLoadingIndicatorFullScreenModalBar`, owned by `SMASHWebContainer`. Its direct visible child is one image-backed `UIImageView` using a `448×1024` grayscale skeleton raster.

This explains why PDP CSS cannot fix the screenshot: the bad frame exists in native UI before the destination DOM paints.

## v7.407 correction
- Add an exact `IESSkeletonView` owner only when it is a near-full-screen child of `AWLoadingIndicatorFullScreenModalBar` in `AppCXWindow`.
- Keep that skeleton view OLED black.
- Claim only its direct grayscale skeleton image family (captured `448×1024`, with a bounded size/aspect tolerance).
- Transform that raster once at mount: invert the light grayscale skeleton and apply a small black attenuation so the stock white floor becomes OLED and the stock gray placeholder bars become medium/dark gray, visually matching the existing Home hero skeleton language.
- Preserve the yellow Amazon loading/progress strip; it is not a child of the raster owner and is not modified.
- Cache the original and transformed image on the exact image view and restore the original if the view is ever reused outside this owner.

## Architecture / performance
The correction is event-driven through existing UIKit lifecycle/image assignment hooks. The raster transform is performed once per skeleton image assignment. No MutationObserver, timer, polling loop, RAF, Web scroll listener, recurring hierarchy scan, generic full-screen image filter, or new WKUserScript is added.

## Probe refresh
FULL, VIEWPORT and TRANSITION identities/receipts/helpers are regenerated as v7.407.

# AmazonDark v7.414 — location navigation renderer fix

Direct parent: **v7.413~address-location-compile-fix**.

This release uses the supplied v7.413 FULL, VIEWPORT and TRANSITION evidence to correct the current AppCX/Nile location-navigation renderer without broadening into unrelated React sheets.

The current location stack mounts inside an `AppCXBottomSheet` whose `SNPRootView` is roughly 430×763. Older location ownership required an SNPRootView at least 85% of screen height, so this real bottom-sheet root was rejected. v7.414 instead recognizes the exact `AppCXBottomSheetContentView` + `WrappedNileFeatureContainer` + `navigation-root` structure and performs one bounded initial prime; later ownership remains event-driven through existing React lifecycle/setter hooks.

Fixes:
- Choose Your Location address cards are committed through React's own background setter and invalidated at both UIView and CALayer display levels, preventing the stock-white border/background raster from flashing or remaining stuck even when the model background already reports black.
- Neutral address-card text, including names/addresses that sometimes hydrated dark, is corrected at assignment and final draw/layout. Authored blue links remain blue and the selected orange border is preserved.
- Enter a US zip code uses a dark-gray input with gray React border and light text/placeholder; Apply is OLED with a gray React border and light text; header text is light; its separator is gray; the authored back chevron is untouched.
- Ship outside the US neutral list/card surfaces are OLED, neutral text/section headers are light, and neutral dividers are standardized gray while authored icon/chevron/color states are preserved.

No production MutationObserver, timer, RAF loop, Web scroll listener, polling loop, recurring hierarchy traversal, or new WKUserScript family is added. FULL, VIEWPORT and TRANSITION probes are regenerated to v7.414 and remain separate workflows.

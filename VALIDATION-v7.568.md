# AmazonDark v7.568 — Grocery OLED and capture boundaries

Base: origin/main e22e6232 (v7.567). Keyboard and prior Pharmacy/map fixes retained.

## Evidence and changes

The two supplied v7.567 FULL archives both completed as **partial** captures with one visible WebView and child-frame payloads. They contain the grocery deals/storefront, quantity controls, and delivery upsell sheet. Their exact DOM families now receive OLED floors, white neutral copy, gray borders/dividers, and OLED plus controls. Product/editorial rasters use the existing user-controlled brightness formula. The upsell raster is tamed through background blending so its overlaid action remains legible. The native header's probe-recorded green floor is replaced on the same three chrome owners already used for Pharmacy; the logo is untouched.

The APLF navigation chooser gains a route-scoped standard AUI popover rule. Its owner mapping still requires a new capture to verify; no unseen DOM classes were claimed as probe-confirmed.

## Capture repair

Code inspection found that a screenshot while FULL was busy was rejected. An armed VIEWPORT waited behind that scan, potentially missing the foreground boundary. These now create independent immediate native/main-Web evidence without modifying the active scan's offsets or transport. They terminate as exportable **partial** captures with time/node limits and explicit child-frame limitations. An older FULL completion cannot overwrite the newer receipt. Native discovery includes connected scene windows. FULL records visible DOM before starting each renderer's walk. The immediate collector uses a WeakSet, a bounded queue, an 80 ms budget, 8,000 visited-node limit and 1,800 record limit; it includes open shadow roots.

This is not a claim that every menu has now been verified on-device. The In-Store home and In-Store Code screenshots have no matching supplied probe records. Recapture them on this build; their exact owners, +List controls and QR-specific exclusions remain pending. QR/payment codes should retain scanner contrast rather than receive photographic dimming.

## Validation

Strict local validation passed 221 regressions, including Objective-C++ payload syntax preflight, emitted JavaScript parsing, grocery CSS cascade/semantic exclusions, artwork strength bounds, and execution against a dense 9,000-element diagnostic fixture. The probe source byte ceiling was retired in favor of bounded execution checks; existing recurring-work guards remain.

No native Theos package build or iPhone visual verification was available here. The source ZIP is ready for the existing GitHub CI build workflow.

# AmazonDark v7.0.14

Dark-Reader-free static theme rebuilt around the proven v5.446/v6.0.185 visual contract.

## v7.0.14 corrections

- Restores persistent OLED WebKit canvas ownership on `WKContentView`, following the v6.0.12 fix for white first-composition/recycled frames.
- Restores the proven Home product-card shell prepaint families from v6.0.36 and v6.0.210/211 while keeping actual hero/ad/creative/media planes Amazon-owned.
- Restores the v5.446/v6.0.5 status-bar light-content ownership model with cached per-controller-class claims.
- Restores the v6.0.28 `ANXTopNavBackgroundView` dark lock so Amazon's adaptive transparent-nav hydration cannot turn the top chrome light.
- Strengthens bar-sized native chrome ownership so top and bottom material/blur surfaces resolve against OLED black.
- Restricts `UIWindow` black backing to Amazon's primary normal-level navigation window; transient screenshot/share/input windows are no longer globally painted black.
- Reasserts OLED black only on known Amazon navigation/root controllers during appearance, rather than painting every `UIViewController`.
- Bottom navigation retains OLED background plus selected-light / unselected-Amazon-blue glyph behavior.
- Search field remains gray with black text and black search/camera/mic/location glyphs.
- No Dark Reader runtime, MutationObserver, scroll repair, RAF loop, interval, or generic live DOM walker is used.

The SpringBoard launch cover and JIT/120 Hz infrastructure remain retained from the v6.0.185 lineage.

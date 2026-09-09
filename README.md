# AmazonDark v7.382 — sponsored carousel precision

Direct parent: v7.381 sponsored-slot collapse + Home ad first-paint floor.

This release keeps the successful OLED Home ad-loading floor but corrects the sponsored-content blocker so a sponsored descendant cannot erase an entire recommendation/window/mosaic carousel card.

Key correction:
- `isSponsoredProduct` now requires the explicit JSON value `true`.
- generic `:has(any ad marker)` outer-slot collapse is removed.
- dashboard owner collapse is limited to direct widget roots with explicit ad-slot identity.
- window tiles use the same narrow `single-creative-card` / `single-video-card` + feedback-label ownership semantics used by AmznKiller's selector list.
- mosaic owner collapse is only allowed when the direct widget root is itself an explicit ad placement; nested sponsored products do not kill the whole card.

No recurring DOM observer/scanner/timer was added. Price History, current theming, checkout/BYG fixes, launch/switcher policy, and universal probes are preserved.

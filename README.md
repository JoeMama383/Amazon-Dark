# AmazonDark v7.381 — sponsored slot collapse + Home ad first-paint floor

Direct parent: `7.380~amznkiller-features-optimization-audit`.

This is a narrow follow-up to the new sponsored-content preference. It preserves the v7.380 theming, price-history feature, checkout dedupe, teal transition forensics, launch policy and universal probes.

## Probe-proven Home issue

The v7.380 VIEWPORT capture identified the blank ad placeholders as real Home DOM layout slots, not UIKit/WebKit backing planes:

- the first dashboard `li.gwm-tile` is about 161x215 and still paints white after its sponsored child is hidden;
- the second dashboard `li.gwm-tile` is the same white shell, with `md-grid-2` beneath it carrying the `mobile-gateway-atf_ad-...` family;
- the lower empty card is the center `li[class*=_hp-mosaic-container_style_widgetContainer]`, about 327x468, whose inner sponsored content has been hidden while the owning list item remains.

## v7.381 correction

- The always-on document-start theme owns `#gwm-dashboard > li.gwm-tile` background as OLED black. This is deliberately independent of the sponsored-content preference, so ads that are allowed to load no longer sit on a bright-white transition shell.
- With **Hide Sponsored Content** enabled, AmazonDark now collapses the owning dashboard/window/mosaic list item when it contains a positive ad descendant. Hidden descendants still satisfy CSS `:has()`, so the parent disappears without a MutationObserver, timer, polling pass or DOM removal loop.
- Positive markers include Amazon ad metadata already used by the v7.380 blocker plus the probe-captured `mobile-gateway-atf_ad-` family.
- The outer-slot rule intentionally does **not** use a generic `[class*=sponsored]` heuristic. The probe shows ordinary mosaic product cards can contain an `asin-sponsored-badge-empty` placeholder, so treating every `sponsored` class as proof would delete legitimate cards.

## Runtime contract

No new MutationObserver, timer, RAF, scroll listener, recurring scan, network hook, fake control, app-switcher cover, warm-splash suppression or broad image/theming rule is added. The change is declarative CSS installed at document start.

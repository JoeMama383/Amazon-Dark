# AmazonDark v7.380 audit

## Scope preserved
Existing Home/Search/Product/Cart/Person/Menu/Alexa/Checkout theming is unchanged except the structural duplicate-checkout guard. TWB factor/shade mappings from the Claude audit remain regression-locked. The v7.350 AXU/Tez splash seal remains. v7.379 teal transition diagnostics remain read-only.

## AmznKiller research outcome
The upstream project removes sponsored content with cosmetic CSS/selector injection, provides Keepa/CamelCamelCamel price-history charts, and uses Android GPU force-dark plus supplemental CSS for its experimental dark mode. Only the first two concepts are appropriate to port to iOS. AmazonDark does not adopt Android Force Dark because reproducing it with generic CSS inversion would regress authored media/dynamic colors.

### Hide Sponsored Content
Default off. A single style node is injected at document start only when enabled. It targets high-confidence Amazon ad/sponsored markers already represented by current Amazon DOM/probe families. It does not make network-blocking claims.

### Price History
Default off. A one-shot main-frame script extracts a 10-character ASIN from product inputs or `/dp|gp/product|gp/aw/d/` paths. It supports Amazon US/UK/DE/FR/JP/CA/IT/ES/IN/MX/BR; Camel also gets AU while Keepa is omitted there if a supported Keepa product-domain ID is unavailable. Charts use lazy images and no observer.

## Duplicate checkout
The old presenter-specific check could miss a duplicate request routed through a different presenter. v7.380 walks the current presented-controller chain at presentation time and suppresses a new AMS checkout only if a live, non-dismissing AMS checkout already exists. This is O(depth) on one presentation event, bounded to 16 controllers, with no debounce/timer.

## Teal switcher
No production guess was added. The current build retains: 120-second transition recording across background/foreground cycles, synchronous window/presentation-plane snapshots at lifecycle edges, passive SpringBoard XIB observation returning `%orig` unchanged, and `SceneContent` pass-through. No OLED cover is present.

## Dead/duplicate/performance audit
- duplicate static function definitions: 0
- duplicate `%hook` class blocks: 0
- obviously dead static function definitions: 0
- new-feature MutationObservers: 0
- new-feature intervals/timeouts/RAF/scroll listeners: 0
- production compiler remains `-Os`; linker dead-strip remains enabled
- historical root audit/probe-diff files removed from source handoff; regression tests retained

The universal probe's two self-recursive dispatch blocks still produce ARC retain-cycle warnings during compilation. They are explicit-trigger probe code, break their byref cycles on completion, and are never active in normal runtime; production hot-path behavior is unaffected. They were not rewritten in this release because changing capture sequencing would risk probe fidelity while the teal investigation is active.

## Packaging
The v7.379 GitHub failure was packaging-only: `postinst` mode 0644/0666 is invalid for a Debian maintainer script. v7.380 ships it as 0755, validates executable mode, and CI normalizes it immediately before packaging.

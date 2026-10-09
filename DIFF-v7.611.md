# AmazonDark v7.611 — Your Saves / Lists and Registries OLED repair

**Parent:** v7.610 complete source. **Evidence:** v7.605 independent VIEWPORT r8, which contains the actual WebKit DOM for the Lists and Registries / Your Saves view.

## UI rules added

- New declarative `src/ADYourSaves7611.js` / `.js.inc`, injected after v7.609. It only activates when both `#lists-list-carousel-header-button-row` and `#awl-list-items` exist.
- Pale `div.lists-carousel-container` and original `.lists-carousel-element .a-box` card floors → OLED black; original gray borders retained/recolored, not duplicated.
- List cards/labels/product titles/prices/delivery neutral body text → white; secondary copy → legible gray. Blue links, orange stars/Prime check, sale/stock reds, bestseller badge, and other semantic colors remain unchanged.
- `#ys-filters-scroller` Filters, All, Deals, Limited Availability, Trending pills → neutral medium gray with gray borders, white text. Selected `All` retains its authored blue border and selected state.
- Filter dropdown icon, icon-only create (+) control, and positively labeled Close/Dismiss controls → neutral-white glyphs, no size/location/geometry changes.
- Saved-product actions: existing Add to Cart and overflow button floors → OLED with gray existing borders and white neutral text/icon graphics.
- Existing dividers → `#494d4d`; no pseudo-elements, extra lines, dimensions or rounding changes.
- Real images `img.lists-list-carousel-image` and product thumbnails inside `.lists-saves-item-image` receive the preference-controlled TWB `brightness(factor)` exactly once at the image level. The CSS does not delete image data or alter visibility/positioning.

## FULL/VIEWPORT forensic explanation

- The supplied TAR is **VIEWPORT**, not a FULL export. The reason in its first line is `armed-background-during-full`: the user backgrounded Amazon while a FULL capture was in progress.
- Source `ADUIScanWebViewFull7364` explicitly stops when `UIApplicationStateActive` becomes false; the WebKit root/overflow walker cannot continue foreground scrolling after app backgrounding. It may thus export partial evidence rather than an entire walk. The r8 DOM is readable and its document is ~1788px high, so inability to identify the renderer is not the issue established by this capture.
- v7.611 appends `FULL_INTERRUPTED_BY_BACKGROUND` to the active FULL report at the actual `DidEnterBackground` boundary. It changes **diagnostics only**, preserving screenshot=FULL and armed-background=VIEWPORT independence. This does not purport to make a backgrounded WKWebView scrollable.
- To test FULL coverage: leave Amazon on Your Saves, take a screenshot, keep Amazon foregrounded until FULL completes, then export FULL. Run a separately armed VIEWPORT only afterward. To diagnose any failure despite remaining foregrounded, provide that FULL TAR.

## Guardrails

No new DOM walkers, timers, observers, recurring scans, geometry edits, sprite replacements, or global color overrides. Existing v7.609 media/sort and v7.610 profile/notification changes remain included. Removed one unused `ADProfilePickerRow7610` helper whose dead static body triggered the existing CI dead-function test; active ownership methods were unchanged.

# AmazonDark v7.557 validation

Static validation targets:

- package/runtime/probe identity synchronized to v7.557;
- selected Filters cascade keeps gray fill + authored blue selected border;
- Price histogram change is floor-only;
- redirected Account classification is physical/foreground-gated and reuses Person ownership;
- FULL Person routing rejects a covered `#me` root;
- VIEWPORT arm consumption precedes busy-capture handling and queued viewport state is export-visible;
- no new production MutationObserver, interval, RAF, scroll listener, or recurring hierarchy scan;
- existing historical regression suite remains intact.

On-device verification after CI/package install:

1. Open Filters > Sort by: Featured should match the other medium-gray option fills, retain its blue selection outline, and keep white text.
2. Open Filters > Price & Deals: All Prices should behave the same; the price histogram panel floor should be OLED black while blue graph/slider geometry and white price text remain unchanged.
3. Open Person > Account: Account heading, section headings, cards/rows and white floors should use the existing Person dark treatment without changing authored media/accent colors.
4. Take a FULL screenshot while Account is visible and leave Amazon foregrounded until the sweep completes; the capture should target the visible Account surface rather than the retained hidden `#me` page.
5. For VIEWPORT, arm it, leave Account visible, and background Amazon once. If FULL was still winding down, export may briefly report queued/running; retry export after a few seconds rather than re-arming immediately.

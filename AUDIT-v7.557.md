# AmazonDark v7.557 audit — Filters / Account / universal probes

## Evidence reviewed

- `AmazonDark-v7.556-ui-full-probe-20261003-124146-275-r1.tar` — completed FULL capture, about 20 MB; it is the Filters **Price & Deals** sheet, not Account. The larger size is the mounted-DOM catch-up/full inventory rather than an Account-specific capture.
- `AmazonDark-v7.556-ui-viewport-probe-20261003-122921-590-r3.tar` — Filters viewport capture.
- User screenshots of Sort, Price & Deals, the failed VIEWPORT export sequence, and Account.

## Filters diagnosis and repair

The selected controls escaped v7.556 because they are `span.sf-filter-floatbox.s-filter-item-selected` while v7.556 normalized only `a.sf-filter-floatbox`.

v7.557:
- normalizes both anchor and span floatboxes;
- gives selected Featured / All Prices `#303335` fill and white text;
- deliberately does not write a selected border, so Amazon's blue selected outline remains authoritative;
- excludes selected anchors from the older v7.556 border-color owner for the same reason;
- changes only the exact `#priceRefinements #filter-p_36 > .sf-filter-section.s-no-js-hide` floor to OLED black, leaving slider descendants unpainted.

## Account diagnosis and repair

The screenshot is consistent with a pushed React/Person page while Amazon retains the main `RCTScrollView#me` beneath it. Existing Person theme semantics already own the corresponding card/floor/text families, but their root classifier previously required ancestry under `#me`.

v7.557 adds an event-driven redirected Person root proof:
- find a large foreground React scroll ancestor of the currently painted view;
- find the separate retained `#me` root in the same window;
- reject ancestor-related roots;
- use a bounded 3×3 hit test to require the candidate to own the foreground while `#me` does not;
- cache only the positive redirected root and then reuse the existing Person surface classification/theming.

This does not add a timer, observer, polling loop, recurring hierarchy scan, RAF loop, or scroll callback.

## FULL probe repair

`ADUIPersonWrapper7519()` previously accepted a geometrically visible `#me`, even when a pushed Account page physically covered it. That could route FULL into the hidden Person canvas.

v7.557 requires a bounded foreground-majority hit test before `#me` can win the dedicated Person route. Covered Person roots therefore fall through to the universal visible-renderer route, which can inspect the Account page.

## VIEWPORT probe repair

The supplied terminal screenshot shows the exact v7.556 failure mode: FULL was still busy, then VIEWPORT was armed and Amazon backgrounded, but `ADUIHandleWillResignActive7447()` returned on `gADUIProbeBusy7362` **before consuming the arm**. Export therefore had no viewport state to find.

v7.557 consumes the arm first. If another capture is active it records VIEWPORT as queued and holds the background task. If the active capture is FULL, backgrounding makes that old walk obsolete, so its existing cooperative deadline is shortened to 2.5 seconds. On completion, the queued background-boundary VIEWPORT launches instead of being dropped.

## Performance contract

Production theming remains event-driven. The new physical tests are bounded and are entered from already-existing paint/classification paths or explicit probe triggers. No ongoing DOM walker or production traversal machinery is introduced.

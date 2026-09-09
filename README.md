# AmazonDark v7.380 — AmznKiller features + optimization audit

Direct parent: `7.379~teal-transition-forensics-claude-audit`.

This release preserves the existing probe-proven AmazonDark visual contract while adding two default-off shopping features, hardening checkout presentation dedupe, fixing package-script permissions, and auditing the production source for dead/duplicate hot-path code.

## Optional shopping enhancements

- **Hide Sponsored Content**: one declarative document-start stylesheet. It collapses high-confidence Amazon sponsored/ad containers and does not block network requests. No MutationObserver, timer, RAF, scroll listener, polling, or recurring scan.
- **Price History**: one main-frame, one-shot product-page injector. It extracts the current ASIN and adds an OLED-styled collapsible panel with lazy Keepa and CamelCamelCamel chart images. The ASIN is sent to those third-party services when enabled.

Both preferences default to off and live under **Shopping Enhancements** in AmazonDark settings.

## Theming architecture decision

AmznKiller's Android Force Dark is not ported. Its broad coverage relies on Android GPU-level force-dark behavior, which has no equivalent safe iOS API for this tweak. AmazonDark therefore retains its current cheap global OLED WebKit/native floors plus narrow probe-proven interface owners instead of reintroducing global inversion/filter heuristics.

## Checkout duplicate-loading/presentation hardening

The checkout dedupe is now structural rather than tied only to one remembered presenter. A new AMS checkout presentation is rejected only when another live, non-dismissing `AMSModalLayoutFullScreenViewController` is already in the current presentation chain. No time debounce or timer is used.

## Teal app-switcher issue

No cover, fake snapshot, warm hide/show behavior, or scene replacement is introduced. The v7.379 120-second cross-background transition recorder and passive SpringBoard XIB observation remain intact so the next bad run can identify the real source. Saved `SceneContent` remains pass-through.

## Optimization / source cleanup

- production uses `-Os`, `-ffunction-sections`, `-fdata-sections`, and linker dead stripping;
- no duplicate `%hook` class blocks or duplicate static function definitions;
- no obviously dead static production function (every static definition has a live reference);
- optional new features add no recurring runtime work;
- old release-audit/probe-diff documents were removed from this handoff because Git history already preserves them;
- current universal FULL/VIEWPORT and transition probes are retained.

## Build reliability

`layout/DEBIAN/postinst` is mode `0755`. CI normalizes that mode before validation and packaging, and `scripts/validate.sh` rejects a non-executable maintainer script. Strict CI continues to run Logos lint and the full Python regression suite before Theos packaging.

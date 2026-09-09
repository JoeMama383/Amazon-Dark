# AmazonDark v7.383 — sponsored selector rules

Direct parent: v7.382 sponsored-carousel precision.

This release fixes the sponsored-content blocker without changing the successful v7.381 OLED Home ad-loading floor or the v7.382 mixed-carousel preservation rules.

The v7.382 blocker accidentally placed two nested `:has()` selectors inside one comma-separated CSS selector list. Nested `:has()` is invalid CSS, and one invalid selector invalidates the entire ordinary selector list, so the toggle could leave every sponsored item visible.

v7.383 fixes that at the architecture level:
- no nested `:has()` selectors;
- each sponsored selector is emitted as its own CSS rule so one bad/unsupported family cannot disable the others;
- the current AmznKiller sponsored/ad selector families are covered, including mobile thematic bundles, `sb-*`, loom slots, featured ASIN/video families, APE/safe-frame placements, and exact `isSponsoredProduct:true` matching;
- only narrow probe-backed Home dashboard owners are collapsed at the outer `li.gwm-tile` level;
- normal mixed recommendation/mosaic cards are never removed merely because they contain a nested sponsored child.

No MutationObserver, recurring scanner, timer, RAF loop, scroll hook, app-switcher cover, or broad theming change was added. Price History, checkout/BYG fixes, launch/switcher policy, and the universal VIEWPORT/FULL probes are preserved.

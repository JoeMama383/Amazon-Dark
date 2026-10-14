# AmazonDark v7.639 — Search/PDP production rendering scope

Base: v7.638-render-work-queue-repair. Release goal: reduce *actual production* WebKit CSS selector matching/recalculation workload on the slow Search → product entry path, not expand any probe.

## Source changes

1. **Search + Home skip four PDP-only JavaScript styling programs in main documents.** The existing scripts are wrapped through `ADSkipPDPOnSearchHome7639` at concatenation time. That helper bypasses execution only for main-document pathname `/`, `/s`, or `/s/...`. Product details on `/dp/...` and other/unknown paths continue to receive the existing programs. Child frames retain the original code (important for ad rendering). The four isolated programs are `ADPDPCompletionJS7405`, `ADPDPCompletionTWBJS7405`, `ADPDPUICompletionJS7439`, and `ADPDPMainResidualJS7440`. `ADPDPProbeBackedFixesJS7458` is deliberately *not* gated because it carries Returns and other owners.
2. **Remove 164 verified unrelated CSS rules from the live main-frame Search/PDP `ad7482-new-menus` sheet.** All authored CSS selectors, declarations, and cascade order are identical to v7.638; only three release-tag comments were stamped to v7.639. At document start, only `/s`, `/dp`, `/gp/product/...`, and `/gp/aw/d/...` main documents drop the rules whose *entire* selector lists belong to unrelated One Medical/Warbler, account confirmation, Deals and Memories root families. Search/PDP survivors preserve original selector order, declaration values, and specificity. Other document routes and every child frame install the complete original sheet and keep those 164 rules.
3. **Keep actual OLED theming and capture paths intact.** No changes to native floors, black loading screen, existing RGB/semantic colors, TWB image settings, borders, markup geometry, enabled/disabled state, the FULL/VIEWPORT/TRANSITION algorithms or performance recorder instrumentation. Existing versioned diagnostics are renamed to v7.639 only.
4. **Add a v7.639 regression:** execute the exact document-start stylesheet selection with Node on Search, PDP, Home, non-hot menus and child frames; compare full non-hot CSS bytes, 164 removed rules, and preserve Search/PDP leaves. Verify every excluded rule has *all* top-level comma-separated selectors anchored in its explicitly unrelated owner. Golden payload test normalizes only the new route selector, proving retained CSS bytes match the v7.636/v7.638 baseline.

## Evidence and limitations

The **v7.638 normal capture** recorded input arrival up to 2,111 ms, input-to-next-RAF up to 4,068 ms, 3,390 ms event-loop lag and DOM interactive up to 19,285 ms. Native theming hooks were small, and main-document theme work installed cheaply (<~12 ms). It contained 47 theme style elements and 1,374 top-level rules in a single main document. This does **not** prove exactly which style caused each stall. The v7.638 style-cost experiment forced recalculations, ranking the large menu/other sheets, but those artificial results are not everyday input latency.

This is a **real production CSS-work reduction**, not a diagnostic-only build. It is not a verified cure for all latency: actual iOS 17 device results are required. Desktop/Node regression coverage proves route CSS source composition, not hardware present times. No installable `.deb` is linked or executed locally; GitHub Actions handles Theos compile/link/package after manual push.

## Versioned files

`src/Tweak.xm`, `src/ADNewMenus7482.js.inc`, `src/ADSkeletonProbe7339.h`, `src/ADPerformance7596.inc`, standard probe payload headers/version references, scripts, `README.md`, `layout/DEBIAN/control`, `COMMANDS.md`, and the two new v7.639 docs/test.

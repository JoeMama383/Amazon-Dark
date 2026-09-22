# AmazonDark v7.448 validation

Direct parent: `v7.447~probe-responsiveness` (`AmazonDark-v7.447-probe-responsiveness-source.zip`, SHA-256 `afd681677a1292e596e10234c525da689e36416424e086a6b8b878b2613205cc`).

## Scope

Dedicated performance consolidation only. Preserve v7.447 theming and probe/export behavior while reducing redundant post-v7.388 Web payload, making PDP child-frame delivery cached/idempotent and PDP-gated, caching the page content world, and replacing explicit diagnostic front-removal queues with cursor queues.

## Static performance delta

- `src/Tweak.xm`: 861,712 -> 853,010 bytes (-8,702 / -1.01%).
- Core document-start Web program: 208,738 -> 205,874 bytes (-2,864 / -1.37%).
- Checkout floor program: 69,983 -> 63,571 bytes (-6,412 / -9.16%).
- Default installed Web payload: 280,135 -> 270,859 bytes (-9,276 / -3.31%).
- All-feature Web payload: 313,468 -> 304,192 bytes (-9,276 / -2.96%).

## Runtime mechanism counts

- `new MutationObserver(`: 0
- `createTreeWalker(`: 0
- Web `addEventListener('scroll'`: 0
- `setInterval(`: 0
- `requestAnimationFrame(`: 0
- production `setTimeout(`: 0
- `querySelectorAll(`: 1 existing bounded call site
- `dispatch_after(`: 1
- `dispatch_async(`: 4
- Logos hooks: 80 plus 2 `%hookf`

## Validation

- `bash scripts/lint-logos.sh`: PASS.
- `sh -n scripts/ui-probe.sh`: PASS.
- `sh -n scripts/skeleton-probe.sh`: PASS.
- `sh -n layout/DEBIAN/postinst`: PASS.
- All **126** `tests/test_*.py` regression files: PASS against the final source in bounded chunks.
- v7.386/v7.387 semantic Web goldens and all 86 sponsored-selector rules: PASS.
- v7.388 native-work/pref-planner optimization tests: PASS.
- v7.440 PDP child-frame ownership and v7.448 cached/idempotent delivery tests: PASS.
- v7.446 bounded FULL responsiveness and v7.447 background-safe VIEWPORT/TAR contracts: PASS.
- Generated universal main-frame/cross-frame JavaScript compile/Node-parse regressions: PASS through the inherited strict tests.
- Exact-parent diff whitespace diagnostics: none.

## Build boundary

A local Theos build cannot run in this container because `$(THEOS)/makefiles/common.mk` is unavailable. GitHub Actions remains authoritative for the real arm64/arm64e compile, link, sign, and rootless package stages. No measured device FPS/launch/energy claim is made by this static optimization pass.

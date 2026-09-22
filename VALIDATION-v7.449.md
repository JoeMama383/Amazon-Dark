# AmazonDark v7.449 validation

Direct parent: `v7.448~performance-consolidation` (`AmazonDark-v7.448-performance-consolidation-source.zip`, SHA-256 `c775f123a1f2254d9fb2a94b851443ec0f8db219452b41f899751be35c520f28`).

## Scope

Correct only the explicit FULL diagnostic architecture: eliminate the screenshot-triggered synchronous native hierarchy spike, stop performing a whole-document Web traversal at every scroll step, move complete DOM inventory after lazy-load convergence, and add bounded catch-up/reconciliation for content mounted during later scrolling. Preserve v7.448 production theming/performance behavior and v7.447 VIEWPORT/TAR workflow.

## FULL architecture checks

- Initial FULL native hierarchy capture uses `ADUINativeSnapshotAsync7449`; the screenshot path no longer performs the old synchronous full native dump.
- Native scroll-candidate discovery uses `ADUINativeScrollCandidatesAsync7449`.
- Native per-candidate subtree snapshots are cooperative.
- Per-scroll Web sampling uses the bounded `ADUIProbeViewportSample7449` hit-test program and contains no `TreeWalker` / `querySelectorAll` traversal.
- Root convergence monitors scroll extent plus DOM node count.
- The final complete mounted-DOM inventory runs only after root convergence (`FINAL_FULL_DOM`).
- Main final collector ceiling: 120,000 elements; cooperative batch ceiling: 32 elements / about 3 ms.
- Nested overflow owners are swept after final inventory and restored independently.
- `WeakSet`-backed `FINAL_CATCHUP_DOM` skips already serialized nodes before computed-style work.
- One post-inventory root-growth reconciliation path is present.
- A stalled nested owner is skipped/marked partial rather than aborting the entire capture.

## Validation

- `bash scripts/lint-logos.sh`: PASS.
- `sh -n scripts/ui-probe.sh`: PASS.
- `sh -n scripts/skeleton-probe.sh`: PASS.
- `sh -n layout/DEBIAN/postinst`: PASS.
- Generated universal main-frame and cross-frame probe programs compile/parse through inherited regression gates: PASS.
- New bounded viewport-sample include compiles under gnu++98 and parses under Node: PASS.
- `tests/probe_responsiveness7446.cjs` final-full / owner restore fixture: PASS.
- All **127** `tests/test_*.py` regression files: PASS against final source in deterministic bounded chunks.
- Inherited v7.386/v7.387 visual goldens, v7.388 performance architecture, later checkout/payment/location/PDP/SafeFrame families, v7.446 bounded probe contracts and v7.447 VIEWPORT/TAR contracts: PASS.

## Runtime architecture

No production `MutationObserver`, Web scroll listener, polling loop, `setInterval`, RAF loop or recurring hierarchy scanner is introduced by v7.449. The heavier walkers remain explicit-probe-only and finite.

## Build boundary

The local execution environment does not contain Theos makefiles, so GitHub Actions remains authoritative for arm64/arm64e compile, link, sign and rootless packaging. Device responsiveness and final-document coverage are not claimed until the Actions build is installed and exercised on the target Product Detail screen.

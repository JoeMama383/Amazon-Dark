# AmazonDark v7.449 — nonblocking complete FULL probe

Direct parent: **v7.448~performance-consolidation**. Production theming, preferences, PDP ownership, VIEWPORT behavior, TRANSITION behavior, and the plain-TAR export contract are preserved. This release changes the explicitly triggered FULL diagnostic architecture because the v7.448 screenshot path could still freeze long Product Detail pages and could finish before the lazily growing document was fully inventoried.

## Root cause

The old FULL path was bounded in nominal node counts, but two expensive operations were still synchronous or repeatedly global:

- the screenshot trigger immediately serialized a very large native UIKit/React hierarchy on the main thread;
- each Web scroll step restarted a document-root `TreeWalker` and ran computed-style work across large portions of the DOM merely to emit the current viewport;
- the nominal full-DOM inventory occurred before lazy-load scrolling, so content mounted afterward was never guaranteed to appear in the final report.

That combination explains both symptoms: the Product Detail UI could become unresponsive during capture while the exported report could still omit the true final document.

## v7.449 FULL pipeline

FULL now uses a staged cooperative pipeline:

1. **Cooperative native discovery.** The initial native hierarchy is serialized in small ~3.5 ms main-loop batches. The same walk discovers visible `WKWebView`s, avoiding an immediate second hierarchy traversal.
2. **Root-first lazy-load drive.** The main document is scrolled using cheap height / offset / viewport / node-count metrics. It does not perform a whole-DOM `TreeWalker` at each offset. A small bounded `elementsFromPoint` sample is taken only on alternating positions to preserve evidence from virtualized/transient viewport content.
3. **Stable-bottom proof.** FULL requires repeated stability of both maximum scroll extent and DOM node count before considering the root converged.
4. **Final complete mounted-DOM inventory.** Only after convergence does FULL run the cooperative full collector. The main-document ceiling is raised to 120,000 elements and work is yielded in batches of at most 32 elements / roughly 3 ms.
5. **Nested overflow-owner sweep.** Overflow containers discovered by that final inventory are driven separately and their original offsets are restored.
6. **Unseen-node catch-up.** A `WeakSet` tracks elements already serialized. The post-owner catch-up walks the DOM cooperatively but skips already-seen elements before expensive style work, capturing only content that mounted during nested scrolling.
7. **One growth reconciliation.** If the root document grows again after the first final inventory, FULL performs one additional root convergence pass followed by another unseen-node catch-up.
8. **Cooperative native scroller diagnostics.** Native scroll-candidate discovery and per-candidate subtree snapshots also run in small yielded batches rather than large synchronous main-thread dumps.

Cross-origin child/SafeFrame collection remains trigger-only and finite, with higher FULL ceilings and cooperative batching. The original document and nested-scroll offsets are restored when their sweep completes.

## Runtime contract

No production `MutationObserver`, Web scroll listener, polling loop, recurring hierarchy scanner, `setInterval`, or RAF loop is introduced. The heavier collectors exist only after an explicit FULL/VIEWPORT trigger. v7.449 does not intentionally change any production visual rule from v7.448.

## Validation

All **127** `tests/test_*.py` regression files pass against the final source in bounded chunks. A new v7.449 regression explicitly rejects the old synchronous FULL native dump and the old whole-document-per-scroll-step Web collector. Universal main-frame, child-frame, scroll-command, and viewport-sample generated JavaScript compile/parse tests pass.

Device responsiveness and complete real-Amazon lazy-load coverage still require the installed Actions build to confirm; this release does not claim an on-device result before that test.

See `AUDIT-v7.449.md`, `VALIDATION-v7.449.md`, and `COMMANDS.md`.

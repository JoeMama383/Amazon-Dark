# AmazonDark v7.449 FULL probe audit

## Baseline

- Direct parent: `v7.448~performance-consolidation`.
- Parent archive SHA-256: `c775f123a1f2254d9fb2a94b851443ec0f8db219452b41f899751be35c520f28`.
- Scope: diagnose and correct FULL screenshot-probe freezing/incomplete-document behavior without changing production theming.

## Root cause 1 — synchronous native FULL serialization

The screenshot FULL entry point still invoked a rich native hierarchy snapshot synchronously. A Product Detail screen can contain a large UIKit/React tree; serializing geometry, layers, colors, images and metadata for tens of thousands of views in one main-thread call defeats the apparent outer probe bounds and can freeze interaction.

v7.449 replaces the FULL native snapshot and native scroll-candidate discovery with cooperative main-loop walkers. They process bounded batches under a small time budget, yield, then resume. Per-candidate native subtree snapshots use the same cooperative mechanism.

## Root cause 2 — global Web walk at every scroll position

The old FULL Web sweep called the generic viewport collector at each document offset. Although the collector emitted only viewport-relevant rows, it still began a `TreeWalker` at the document root and performed computed-style work while searching for those rows. On a long PDP, every scroll step could therefore revisit a very large portion of the same DOM.

v7.449 drives root lazy loading with cheap scroll metrics only. Alternating offsets use a bounded hit-test sampler (`elementsFromPoint`) capped to a small deduplicated set; no TreeWalker or `querySelectorAll` is used by that per-step sampler.

## Root cause 3 — full inventory occurred too early

The earlier `INITIAL_FULL_DOM` snapshot ran before the root had been fully scrolled. Amazon can mount substantial Product Detail content only after later positions are reached, so a pre-sweep full snapshot cannot prove final-document coverage.

v7.449 reverses the order:

1. drive the root document to a stable bottom;
2. prove stability with both max scroll extent and node count;
3. run `FINAL_FULL_DOM` over the mounted document;
4. sweep nested overflow owners discovered by that inventory;
5. run a `WeakSet`-backed unseen-node catch-up;
6. if root max grows after inventory, reconcile the root once and run another catch-up.

The main final collector ceiling is 120,000 elements with cooperative batches of at most 32 elements / roughly 3 ms.

## Failure behavior

A stalled nested owner is marked partial and skipped rather than aborting the entire FULL capture. Callback timeouts, deadlines and explicit output/node/step ceilings remain finite. Scroll offsets are restored independently for the root and nested owners.

## Cross-frame behavior

The existing child/SafeFrame bridge remains trigger-only. FULL child ceilings are raised and child serialization remains cooperative. Cross-frame reporting remains bounded and does not add production observers, polling, scroll callbacks or recurring traversal.

## Production invariants

The production theming program remains v7.448 except for release identity. The probe changes do not introduce a production `MutationObserver`, Web scroll listener, `setInterval`, RAF loop, polling loop or recurring hierarchy scan.

## Validation boundary

All 127 Python regression files pass in bounded chunks. The new v7.449 test explicitly rejects the old synchronous FULL native dump and whole-document-per-scroll-step Web behavior. This proves the source architecture and inherited contracts, not on-device responsiveness; the installed Actions build still needs device confirmation.

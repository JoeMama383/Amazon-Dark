# AmazonDark v7.448 performance audit

## Baseline

- Direct parent: `v7.447~probe-responsiveness`.
- Parent archive: `AmazonDark-v7.447-probe-responsiveness-source.zip`.
- Parent SHA-256 is recorded in `SOURCE-BASELINE.json`.
- Goal: reduce payload/setup/no-op work without changing accepted theming or probe behavior.

## 1. CSS/document-start consolidation

The post-v7.388 feature additions had accumulated repeated declaration pairs such as a `background` shorthand followed immediately by equivalent `background-color` / `background-image:none`, and a border shorthand followed by the same `border-color`. v7.448 removes only mechanically redundant later declarations. The older semantic-golden Web programs are not broadly minified or rewritten.

Measured static payload deltas:

| Metric | v7.447 | v7.448 | Delta |
| --- | ---: | ---: | ---: |
| `src/Tweak.xm` | 861,712 B | 853,010 B | -8,702 B (-1.01%) |
| Core Web program | 208,738 B | 205,874 B | -2,864 B (-1.37%) |
| Checkout floor | 69,983 B | 63,571 B | -6,412 B (-9.16%) |
| Default installed Web payload | 280,135 B | 270,859 B | -9,276 B (-3.31%) |
| All-feature Web payload | 313,468 B | 304,192 B | -9,276 B (-2.96%) |

## 2. PDP child-frame delivery

The v7.440 ownership path had become a meaningful event-driven hotspot because multiple lifecycle/frame events could request the same child-frame program repeatedly.

v7.448:

- caches the generated forced-frame program by effective white-tame strength;
- records a document-local ownership key so a repeated delivery of the same program exits immediately;
- gates the main trigger on a real `#dp` document before enumerating frames;
- keeps iframe `load`, DOM-ready, one gated `window.load`, and `pageshow` coverage;
- removes the ineffective early `document-start` frame-tree ping;
- caches `WKContentWorld.pageWorld` using `dispatch_once`;
- deliberately retains defensive message-handler reattachment so Amazon-side handler removal cannot strand the owner.

This keeps the existing event-driven ownership model and does not introduce observation, polling, timers, RAF loops, or scroll callbacks.

## 3. Diagnostic queue complexity

Explicit native diagnostic breadth-first traversal previously used `firstObject` + `removeObjectAtIndex:0` in several paths. Because mutable-array front removal shifts the remaining entries, large captures perform unnecessary repeated array movement.

Those diagnostic queues now advance a cursor over the same array. Capture limits, ordering, scope, and termination conditions are retained. This affects only explicitly triggered diagnostics; it is not normal browsing work.

## 4. Preserved v7.388 optimization architecture

The current source retains the v7.388 shared immutable `WKUserScript` cache, selective preference refresh behavior, Search re-entry guard, and checkout no-op appearance guards. It still preserves Amazon/WebKit cache/network ownership rather than clearing or replacing their caches.

## 5. Remaining optimization opportunities

The project is still materially larger than the v7.388 baseline because later UI coverage legitimately added many selectors and narrowly scoped owners. Further reductions should be evidence-driven. The next high-value candidates would be selector-prefix factoring or route-gated program separation, but those carry more cascade/first-paint risk and are intentionally not attempted in this pass without device confirmation.

## Measurement boundary

This audit measures source/program footprint and runtime architecture. It does not claim a measured percentage improvement in device launch time, scroll FPS, memory pressure, energy, or battery life.

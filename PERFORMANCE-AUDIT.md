# AmazonDark v7.625 — performance and architectural drift report

## Conclusion (evidence and limitations)

The **v7.400 audit** describes a static CSS-only Delivery Instructions change and says it introduced no recurring DOM/native hierarchy scans, MutationObservers, intervals, RAF, Web scroll listeners, new WKUserScripts, image filters or polling. That is evidence about the *v7.400 change*, not a complete v7.400 repository-wide token census. The exact v7.400 source archive and same-device v7.400 capture were not available for this handoff. **There is therefore no defensible numerical claim about v7.400 vs v7.625 frame rate, app-start time or time-on-CPU.**

In v7.625 source, a reproducible static census finds **zero** production `MutationObserver`, `setInterval`, `requestAnimationFrame`, `createTreeWalker` and scroll-listener source sites among the enumerated JS modules. The opt-in FULL, VIEWPORT, TRANSITION and performance diagnostics intentionally contain walkers, an observer, RAF and timers; these are dormant outside armed diagnostic windows.

However, there **has been architectural growth**. The current theme includes bounded DOM inventory work and explicit text/paint ownership in hot native hooks. It warrants on-device profiling, not blanket removal, because removing it without menu-level probes risks the specific UI regressions seen after v7.605.

## Current v7.625 source census (source occurrences, not runtime calls)

| Category | Production JS/theme modules | Opt-in diagnostics | Main native Tweak.xm combined |
|---|---:|---:|---:|
| MutationObserver | 0 | 1 | 0 |
| setInterval | 0 | 0 | 0 |
| requestAnimationFrame | 0 | 5 | 0 |
| createTreeWalker | 0 | 6 | 0 |
| querySelectorAll | 8 | 21 | 1 |
| setTimeout | 2 | 6 | 0 |
| dispatch_after | 0 | 30 | 1 |

**Caution:** A native `Tweak.xm` selector match may be inside a JavaScript string, and an opt-in diagnostic can be compiled into a native hook without running until armed. These are grouped source-token counts, not CPU usage or claim of zero native scanning. The `Tweak.xm` main source measures **938,820 bytes** and contains **87 `%hook` tokens**; these totals mix normal and diagnostic responsibilities. The additional 4 hook tokens in `AmazonDarkSB.xm` are not Amazon app scrolling hooks. The historic 7.400 source size and hook count are not available.

## Most plausible hotspots and drift since the v7.400 era

| Priority | Code path | Why it deserves measurement | Current behavior |
| --- | --- | --- | --- |
| High | `RCTView layoutSubviews` (`ADOwnReactView7226`, `ADShopShowOwnView7590`) | Invoked during React view layouts; any owner classification here increases work per layout. | Main-runloop `reactLayoutTheme` timing is recorded while performance capture is armed. |
| High | `UIImageView layoutSubviews` (menu-final media/taming, Shop Show, notifications, overlays) | Image-heavy Home, Search and PDP scrolling repeatedly lays out image views. | `imageLayoutTheme` timing available. |
| High | `UIView setBackgroundColor:` and React text commits | Hot paths during hydration and view updates; many exact owner guards now execute here. | `viewBackgroundInclusive`, `reactTextCommitInclusive` and `labelAttributedCommitInclusive` timing available. |
| Medium | `ADKeepShopping7613.js` | On page activation, scans up to 750 candidate headings and checks local descendant media; may repeat on load while still unmatched. | Event-driven and bounded, not a periodic observer. Removed redundant `picture img` from an existing `img` selector. |
| Medium | `ADReviewBusiness7593.js.inc` | Prime Business Card page can run a bounded 650-element computed-style pass; heading detection on document lifecycle events. | Guarded by page ownership, not recurring. |
| Low | `ADNewMenus7622.js` | At most two delayed ad-feedback checks after a relevant click, one-shot per interaction. | Two setTimeout sites, no polling loop. |
| Diagnostic only | `ADUniversalUIProbe7362`, `ADSkeletonProbe7339`, `ADPerformance7596` | Walkers, observers, timers, frame callbacks and native snapshots can distort measured scroll latency. | Never run UI probes simultaneously with a performance capture. |

## Concrete v7.625 changes

1. **Made version-cutoff handling explicit without changing behavior.** The old inline `${VER#7.}` and new named `CUR=${VER#7.}` **both correctly evaluate to `624` when `VER=7.624`**. Earlier concerns that this inline expansion was broken were unfounded. The cleanup makes the receipt upper bound easier to audit; a synthetic prior-version receipt ARM/EXPORT test now protects that contract.
2. **Restored human-readable performance reporting.** `scripts/performance-report.py` reads one TAR/JSON, summarizes native frame callback gaps, hook call counts, mean/max/histogram P95 bounds, touch age, WebKit document timings, long tasks, resources, input-to-next-RAF, diagnostic interference and missing-data coverage. `--baseline` compares two actual captures.
3. **Restored a reproducible scanner/hook census.** `scripts/performance-source-audit.py` reports code-source occurrences separately for production JS, combined native code and deliberately opt-in probe machinery. Pass `--baseline <source.zip>` for an exact code-to-code comparison once v7.400 source is available.
4. **Eliminated one provably redundant selector**, replacing `img,picture img` with `img` in the exact Keep Shopping media lookup and CSS. All `<picture>` images are already `<img>` descendants; semantic coverage is unchanged.
5. **Added a regression budget** for no production MutationObserver / interval / RAF / TreeWalker / scroll listener and a maximum of eight existing production `querySelectorAll` source sites. Exact UI hooks and the universal probes are not removed.

## Capturing a valid current on-device baseline

Run on the iPhone after installing and opening AmazonDark v7.625:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/performance-probe.sh arm
```

Re-enter Amazon, follow a **repeatable 90-second route** (example: Home scroll for 30 seconds, Your Orders for 30, a PDP for 30). Do not trigger FULL/VIEWPORT/TRANSITION during this window; they have separate purpose and cost. Backgrounding the app also terminates a session.

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/performance-probe.sh export
```

Export produces **one current 7.625 TAR**, not a historical bundle. Read on a PC/Mac with:

```sh
python3 scripts/performance-report.py path/to/AmazonDark-v7.625-performance-SESSION.tar --output performance-report.md
```

To compare future v7.626 etc. use `--baseline old-performance.tar`, matching device, Amazon app version, connectivity, content and actions. Upload the TAR in the chat if you want me to produce a numeric comparison. The v7.400 audit is qualitative, not a captured 90-second performance session.

## Interpretation limits

- `CADisplayLink` gaps are main run-loop callback timing, **not an FPS/hardware presentation counter**; one 33.4ms gap may be a dropped-refresh proxy at 60Hz, but actual display frequency matters.
- Inclusive hook timing lanes overlap and must not be summed to estimate per-frame time.
- `DOMContentLoaded`/`load` are Web navigation timings, not app cold-start metrics; frame/page caches and network differ across devices and routes.
- Probe capture itself adds overhead; avoid mixed captures. The recorder's WebKit PerformanceObserver and RAF run **only while armed** and stop by 90 seconds or app backgrounding.
- The prior historical PDP probe recorded roughly **6,170ms total page performance**, DCL ~5,437ms, load ~6,150ms, 283 resources and 308,576 bytes transferred; this is an earlier isolated capture, not a paired v7.400-v7.625 result.

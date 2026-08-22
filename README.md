# AmazonDark v6.0.213 — full coverage, observer still inert

## What v6.0.211 proved

Neutralising Dark Reader's MutationObserver made the app fast everywhere: products open
instantly, scrolling is seamless. That observer re-themes every node as it arrives, and
Search and PDP hydrate continuously, so it runs on the main thread through exactly the
window where input queues. That is the core performance problem, confirmed on device.

## Why v6.0.212's theming was still broken

Dark Reader has **two** coverage mechanisms and v6.0.210/211 disabled both:

- the **stylesheet proxy** covers sheets that arrive after `enable()`
- the **MutationObserver** covers nodes that arrive after `enable()`

Only the observer was expensive. v6.0.210 measured the proxy as free — no speed change,
no light regressions — and it was left off anyway.

v6.0.212 then exported the generated CSS once, immediately after the first `enable()`,
which is the moment the fewest stylesheets have loaded. Amazon loads most of its CSS
after initial parse, so the published sheet was the thinnest possible snapshot.

## This build

1. **Stylesheet proxy restored.** Measured free; restores sheet coverage.
2. **Export happens as the page settles** — on idle after `enable()`, again after
   `load`, and again on a bounded poll when the element count has grown by half. One
   export per settle, never one per node.
3. **Observer stays inert.** That is the part that cost input latency.

The published sheet is `#ad-drstatic212`, reused rather than duplicated, and
deliberately not `class="darkreader"` so existing `style.darkreader` checks are
unaffected.

## If theming is still wrong

The remaining gap is anything Dark Reader applied as an inline style rather than a rule
— there is no selector to publish for those. That is a finite, enumerable list rather
than a mystery. Name what is still wrong specifically (a card family, a control, a
badge) and each becomes a targeted rule, which costs nothing per mutation.

A rebuild is not warranted. The expensive component is identified and the remaining work
is additive.

## Verification

- Export cadence tested in jsdom against a page growing 50x: published, re-exported as
  it grew, bounded at 2 exports (cap 9), single style element reused, latest CSS live,
  `style.darkreader` still matches nothing. 6/6.
- Observer stub retested: `enable()` runs, its observer is inert, the real constructor
  is restored afterwards and even when `enable()` throws, AmazonDark's observers keep
  working. 5/5.
- Format specifiers unchanged at 9 and 2; payloads parse; balance 0/0/0; lint-logos.

# AmazonDark v6.0.215 — zero per-mutation JavaScript

## What changed

AmazonDark's own three MutationObservers are retired. Every one of them observed
`document.documentElement` with `childList` + `subtree`, so **every DOM mutation on the
page ran a callback** — and Search and PDP hydrate continuously. That is the same shape
as Dark Reader's observer, which v6.0.211 proved on device was the input latency. Ours
were smaller but identical in kind.

Combined with the Dark Reader observer already being inert since v6.0.211, the page now
runs **no JavaScript on the mutation path at all**:

    payload                        live observers   scroll   interval   rAF
    ADDarkReaderBootstrap                0            0         0        0
    ADThreeSymbolsWebJS605               0            0         0        0
    ADWhiteTameWebJS6027                 0            0         0        0

They are replaced by an inert constructor rather than deleted line by line: every call
site keeps its shape, the one-shot initial passes still run, and nothing observes. `new F()`
where `F` returns an object yields that object, so it substitutes cleanly for
`new MutationObserver(...)`, with a fallback to the real constructor if the bootstrap
has not defined it.

## Coverage is now CSS

Late-arriving nodes are themed by the style engine during normal layout, from three
static sheets:

- the document-start floor sheet
- the Dark Reader fixes sheet
- Dark Reader's generated CSS, published on settle (v6.0.213)

Selectors are matched by the engine as it lays out. That is the cheapest mechanism
available and it has no per-node cost.

## What this costs, stated plainly

Anything that only worked because an observer re-ran on later mutations no longer
updates. Specifically at risk: ad-island marking, the checkbox and symbol re-fixes, and
the contrast repair on nodes that appear after the initial pass. Expect some elements to
render unthemed where they previously corrected themselves a moment later.

That is the trade being made deliberately: performance first, then close the visible
gaps with targeted CSS rules, which cost nothing per mutation.

## Verification

- Inert constructor tested: substitution yields an object, the real `MutationObserver`
  is never constructed, `observe()` is a safe no-op, `disconnect()` and `takeRecords()`
  are present, and it falls back to the real constructor when undefined. 6/6.
- Live observer count is 0 in every injected payload; 0 scroll listeners, 0 intervals,
  0 rAF loops.
- Format specifiers 8 and 2; declared-before-use audit clean; balance 0/0/0; payloads
  parse; lint-logos.

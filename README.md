# AmazonDark v6.0.212 — fast path with coverage restored

## Confirmed cause

v6.0.211 neutralised Dark Reader's MutationObserver and the app became fast everywhere:
products open instantly, scrolling is seamless. That observer re-themes every node as it
arrives, and on Search and PDP — which hydrate continuously — it runs on the main thread
through exactly the window where input queues.

Everything else inside Dark Reader had already been eliminated: the stylesheet proxy
(v6.0.210, no change), image analysis (`ignoreImageAnalysis:['*']`), and the theme
object (identical to the fast v5.43.0 build).

## The fix

Keep the observer inert, and replace what it did with something that costs nothing per
mutation.

Dark Reader's generated CSS is **selector-based**. Published as an ordinary stylesheet,
every node that arrives later is themed by the engine during normal layout — no
JavaScript on the mutation path at all. That is the whole difference: same rules,
applied by the style system instead of by an observer.

`exportGeneratedCSS()` is called once, after the first `enable()` settles, on idle so it
never competes with hydration. The result is published as `#ad-drstatic212`, marked
`data-ad-drstatic212`, and deliberately **not** `class="darkreader"` so the existing
`style.darkreader` checks keep behaving exactly as before.

## What may still be light

Anything Dark Reader themed through inline styles rather than a rule has no selector to
publish, so it will not be covered. v6.0.211 showed "a ton of missing and improperly
themed objects" with no CSS published at all; this build should recover most of it. What
remains after this is the real gap, and it is worth listing specifically — a targeted
rule per case is cheap, and unlike the observer it costs nothing per mutation.

## Verification

- Publisher tested in jsdom: stylesheet published, `exportGeneratedCSS()` called exactly
  once despite three invocations, not `class=darkreader`, `style.darkreader` still
  matches nothing, element marked for identification. 5/5.
- Observer stub retested: `enable()` runs and returns, its observer is inert, the real
  constructor is restored afterwards and even when `enable()` throws, AmazonDark's own
  observers keep working. 5/5.
- Format specifiers unchanged at 9 and 2; payloads parse; balance 0/0/0; lint-logos.

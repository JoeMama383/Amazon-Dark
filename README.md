# AmazonDark v6.0.168

Keeps the v6.0.167 proxy change and adds measurement plus a cache write. No behaviour
change to theming.

## Where this stands

v6.0.167 turned the heavy PDP section from *never renders* into *renders slowly* — the
same shape as v5.43.0. So the CSSOM proxy was a real part of it, and what remains is
the one pass Dark Reader cannot skip: parse every stylesheet, walk every element, emit
a theme.

## What this build measures

The page records `performance.now()` either side of `DarkReader.enable()`, plus
stylesheet and element counts before and after, then calls `exportGeneratedCSS()`. The
native side samples that 1.2s after `didFinishNavigation` and appends one line per
navigation to the perf dump:

    DRCOST {"ms":...,"sheets":...,"sheetsAfter":...,"nodes":...,"nodesAfter":...,"cssLen":...,"url":"..."}

## What it caches

The generated CSS is written to `ad-drcache/` beside the dump, keyed by page shape
(`pdp`, `search`, `home`, `cart`, `other`), keeping **two samples per shape**.

Nothing consumes the cache yet, deliberately. The open question is whether one PDP's
generated CSS is reusable on a *different* PDP. Two samples of the same shape can be
diffed to answer that. Shipping a cache that applies before that is known would theme
pages wrong on the device instead of wrong in a file.

If the two PDP samples are near-identical, the cache path is sound: inject stored CSS
at documentStart and skip `DarkReader.enable()` entirely — no stylesheet parse, no DOM
walk, no observer. If they differ substantially, caching is the wrong answer and the
numbers will say so before another build is spent on it.

## Reading it

- `ms` is the honest cost of the pass. If it is seconds, caching wins outright. If it
  is a few hundred ms and the wait is still long, the remaining time is Amazon's own
  hydration and Dark Reader is not the thing left to fix.
- `cssLen` sizes the cache.
- `nodes` vs `nodesAfter` shows how much the page grew during the pass.

## Verification

- Capture region compiles clean under clang against Foundation stubs (exit 0).
- Declared-before-use audit over every `static AD*` helper: clean.
- Both emitted variants of the fixes literal parse as JavaScript.
- All other payloads parse; balance 0/0/0; `scripts/lint-logos.sh`.

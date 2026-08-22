# AmazonDark v6.0.207

Base: **v6.0.185~probe** (`2d9a9c4`). None of 186–205 carried forward wholesale, on
report that v6.0.205 is slower than 185. One idea is taken from it, isolated.

## The input delay

`requestIdleCallback`'s `timeout` does not mean "run within N ms if convenient". When
it expires the callback is promoted to a **deadline task** and forced through even
though the main thread is busy.

Both contrast lanes scheduled through `__AD_IDLE6056__` with a timeout — 260ms and
320ms. During Search-results and PDP hydration the main thread is always busy, so those
timeouts always expire, and the 360/1400-node contrast walk executes exactly while the
page is trying to accept its first tap or swipe.

That matches the reported symptoms precisely: the screen is already loaded, the content
is visible, and taps still do not register.

On PDP and Search the lanes now pass `to === 0`, which is true idle-only: no timeout, so
the callback can never be promoted and waits for a genuinely free frame. Every other
page keeps the historical bounded fallback, so theming still lands promptly where input
is not being contended.

This idea comes from the v6.0.205 experiment. Only this is taken; the other ~700 lines
of that build are left out.

## A note on the first attempt

The initial patch added the hot-page default as `to === undefined`. Both call sites pass
an explicit timeout, so it would never have fired and the build would have shipped as a
no-op. The call sites are now hot-aware individually, verified below.

## Also in this build (from v6.0.206)

Eight `:where(div,span,section):has(> …)` rules, duplicated across both sheets, were
evaluated against every div, span and section in the document and re-run on every
mutation, despite targeting search-result-only components. All 16 are scoped to
`[data-component-type=s-search-result]`. Zero unconstrained `:has()` remain.

## Verification

- Idle lane tested per page type: PDP idle-only, Search idle-only, Home keeps the
  bounded fallback, an explicit timeout off-hot is still honoured, an explicit 0 stays
  idle-only. 5/5.
- Both call sites confirmed hot-aware after patching.
- Selector rewrite tested in jsdom: search-result hosts still themed, Home node no
  longer matched. 4/4.
- All payloads parse; balance 0/0/0; `scripts/lint-logos.sh`.

## If this does not fix it

Then the block is not the contrast lane, and the next suspects are the symbols script's
26 `querySelectorAll` calls and its observer, both of which run during the same
hydration window. Those can be switched off independently rather than guessed at.

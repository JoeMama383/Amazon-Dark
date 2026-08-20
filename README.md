# AmazonDark v6.0.171 — defer the first Dark Reader pass

The change every session since v5.463 has proposed and none has built.

## Why

Dark Reader's initial pass parses every stylesheet and walks every element before it
can paint, on the web process main thread. On a PDP — the largest DOM in the app — that
is what stalls rendering. The bisection supports this and nothing else:

- v5.43.0 fails the same section despite having none of the later machinery
- White Background Taming off: still fails
- the symbols script does not exist in v5.43.0 at all
- tweak fully off: the section renders
- when Dark Reader silently failed to apply while everything else ran, performance
  jumped roughly tenfold

Three builds were then spent trying to measure the pass. All three failed for the same
reason: `didFinishNavigation:` was hooked on `WKWebView`, which never receives it. Rather
than spend a fourth, this build acts on the bisection, which is evidence enough.

## What changed

The `DarkReader.enable` wrapper added in v6.0.169 now defers instead of calling
straight through, so every call site is covered at once. Theming waits for
`readyState === 'complete'`, then runs on `requestIdleCallback` with a 1500ms timeout.
A 3000ms fallback covers Amazon documents that never reach 'complete' because a
long-poll or ad frame keeps them loading.

The documentStart floor sheet already paints the dark background, so the page does not
flash white. It shows dark chrome with briefly unthemed content, then darkens.

**The trade, stated plainly:** content is visibly unthemed for a moment on every page.
That is the cost of not competing with the renderer for the main thread. If it reads as
worse than the current stall, the flag below reverts it instantly.

    touch /var/mobile/.ad_no_defer   theme immediately (pre-171 behaviour)
    rm -f /var/mobile/.ad_no_defer   defer (171 default)

Relaunch after either.

## Verification

- Behavioural test: theming does not run at call time, runs after `load`, paint
  precedes theme, timing still recorded. 4/4.
- Format specifiers and arguments in the bootstrap: 9 and 9, each verified in position
  — the new flag is the 5th, immediately after `__ADNODEFER171__=`.
- Balance 0/0/0, declared-before-use audit clean, all payloads parse, lint-logos.

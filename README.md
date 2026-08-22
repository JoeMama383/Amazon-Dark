# AmazonDark v6.0.211 — Dark Reader observer neutralised

**This is a measurement build, not a shippable state.** Expect light patches.

## Reasoning

Web Dark Reader off makes pages instant, so the cost is Dark Reader's. Inside Dark
Reader:

- stylesheet proxy — ruled out, v6.0.210 disabled it with no change and no light regressions
- image analysis — already off via `ignoreImageAnalysis:['*']`
- theme object — identical to the fast v5.43.0 build

What remains has no setting: Dark Reader's own MutationObserver, which re-themes every
node as it arrives. Search hydrates hundreds of cards and a PDP hydrates continuously,
so it runs on the main thread through exactly the window where taps queue.

## Method

Dark Reader reads the global `MutationObserver` constructor when `enable()` runs, so it
is handed an inert one for the duration of that call only, restored in a `finally`
block. AmazonDark's own observers are created elsewhere and are untouched.

## The trade

Nodes added after the initial pass are no longer themed by Dark Reader. Its generated
CSS is selector-based so most new cards still theme for free, but anything it handled
with inline styles renders light. Light patches while scrolling Home and Search are
expected here.

If taps become instant, the target is confirmed and the real fix is the
`exportGeneratedCSS` cache — theme once, then inject plain CSS with no observer and no
DOM walk, which covers new nodes properly instead of not covering them.

If taps are still delayed with the observer inert, Dark Reader's dynamic mode is not
salvageable for this app and the honest options are the static-CSS cache or a direct
theme.

## Verification

- Stub scoping tested: `enable()` still runs and returns, its observer is inert, the
  real constructor is restored afterwards, AmazonDark's observers still work, and the
  constructor is restored even if `enable()` throws. 5/5.
- Both `enable()` call sites wrapped; format specifiers unchanged at 9 and 2.
- Payloads parse; balance 0/0/0; `scripts/lint-logos.sh`.

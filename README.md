# AmazonDark v6.0.165

Corrects a regression I introduced in v6.0.164 and narrows the one measurement that
still has not been explained.

## Regression fixed: untamed product and ad photos

v6.0.164 replaced the source-scan dedupe in `ADAttachWhiteTameUserScript446` and
`ADAttachThreeSymbolsUserScript605` with an associated-object marker on the user
content controller. `-[WKUserContentController removeAllUserScripts]` is hooked and
re-attaches both scripts afterwards — but the marker survived that call, so both
helpers returned early and **never re-added the scripts**. TWB is White Background
Taming, which is why product photos and the ad creative above them stopped being tamed.

The old scan was self-correcting because it inspected real state. The marker asserted
something that stopped being true. Both helpers are now **byte-identical to v6.0.159**.

## What v6.0.164 proved

**The layout fix worked.** `RCTView layoutSubviews` went from 115.5 µs/call across
3,566 calls (411.7ms) to **1.97 µs/call** across 663 calls (1.3ms) — 58× per call. That
change is kept.

**The attach dedupe was not the 22ms.** `WKWebView didMoveToWindow` measured 16,403
µs/call against 22,347 before; across different sessions that is not a real reduction.
The `containsString:` scan was not the dominant cost, so the diagnosis was wrong.

**Person-raster was never the Reviews cause.** `claims taken=0  contents suppressed=0`
for the whole session, including the Reviews tab. That branch never fired, so it cannot
have been blanking anything. The v6.0.164 suppression condition is kept because it is
strictly the safer of the two, but it is unproven and inert, not a fix.

## New measurement

`WKWebView -didMoveToWindow` is still 508.5ms across 31 calls, now the single largest
entry. Its body is sub-instrumented so the next dump attributes that time precisely:

- `ADTrackWebView613`
- `ADPrimeWebBacking611`
- `ADPreDarken`
- attach symbols script
- build boot `WKUserScript`
- `addUserScript(boot 346KB)`
- attach TWB script

These appear indented under the parent row in the table.

## Still open

The Reviews tab does not fully render, and the cause is not in the native hooks — the
counters rule out the only native path that blanks content. Reviews on a PDP is web
content, so the next place to look is the web side, not this one.

## Verification

- Both attach helpers byte-compared against v6.0.159: identical.
- Nested scope guards compile clean under clang.
- All six injected JS payloads byte-identical to v6.0.159.
- Balance 0/0/0, `scripts/lint-logos.sh`.

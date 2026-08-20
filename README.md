# AmazonDark v6.0.170

## The measurement never ran

`didFinishNavigation:` was hooked inside `%hook WKWebView`. That is a
`WKNavigationDelegate` callback and `WKWebView` never receives it — Logos added the
method and nothing ever called it. So `ADCaptureDRCost168` did not execute in v6.0.168
or v6.0.169, which is why no `DRCOST` line appeared either time, including the line
that was meant to report its own silence.

Sampling now runs from `-[WKWebView didMoveToWindow]`, which the v6.0.169 capture shows
firing 11 times, on a 2.5s delay with a weak reference.

## Attach dedupe, done properly

`attach symbols script` measured 2,456 µs/call and `attach TWB script` 3,818 µs/call —
about 30ms of the 285ms total, and the largest remaining cost that is ours. Both helpers
dedupe by running `containsString:` over every installed user script's source, and
`ucc.userScripts` holds the 346KB Dark Reader bootstrap.

v6.0.164 replaced that with an associated-object marker and broke White Background
Taming: `removeAllUserScripts` drops the scripts, the marker survived, and the helpers
returned early forever. v6.0.165 reverted it.

The marker is sound as long as the hook that drops the scripts also drops the marker.
`-[WKUserContentController removeAllUserScripts]` now clears both markers before
re-attaching. The source scan is kept as a fallback and sets the marker when it matches.

## State of the native side

284.8ms across 29,541 calls for a whole session, `RCTView layoutSubviews` down to
0.62 µs from 115.5. After this build there is nothing left on the native side worth
cutting; the remaining cost is Dark Reader's initial theming pass.

## Verification

- Marker keys declared L1944, used L1950/L2176/L2332 — the use-before-declare check
  that caught the v6.0.167 build failure, now passing.
- Dead `didFinishNavigation` capture site removed; capture defined before its call site.
- Balance 0/0/0, declared-before-use audit clean, all payloads parse,
  `scripts/lint-logos.sh`.

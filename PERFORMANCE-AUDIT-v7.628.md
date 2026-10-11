# AmazonDark v7.627 — captured performance evidence and v7.628 follow-up

This audit is based on **the user's actual v7.627 performance TAR**, not a source-token count.

## Relevant timeline

| UI process event | Offset from capture start | Measured interval |
| --- | ---: | ---: |
| Search-results controller (`SXWebResultsViewController`) appears | ~4.98 seconds | 550.8ms appearance duration |
| Search-results WebView is loading | ~5.02 seconds | **16,525.2ms** loading state |
| PDP (`AMIWebViewController`) appears | ~10.49 seconds | 583.1ms appearance duration |
| PDP WebView is loading | ~10.53 seconds | **19,566.8ms** loading state |
| Performance session ends | 35.74 seconds | background (early termination) |

These overlap and are WebView loading flags, **not proof the scrollbar was disabled for that entire interval**. There is no demonstration yet that the tweak caused the delay; the captured document instrumentation was absent.

## Main-thread findings

- `reactLayoutTheme`: 301 calls, 19.22ms total, mean 0.064ms, max 1.19ms.
- `imageLayoutTheme`: 86 calls, 1.75ms total, mean 0.020ms, max 0.164ms.
- `imageCommitInclusive`: 747 calls, 25.71ms total, mean 0.034ms, max 4.79ms.
- `viewBackgroundInclusive`: 1,208 calls, 13.85ms total, mean 0.011ms, max 0.127ms.
- 13 observed main-runloop callback gaps greater than 50ms in 2,069 sampled intervals (0.63%). Maximum 110.59ms.
- `touchEventAge`: 554 samples, mean 15.21ms, max 59.25ms.

The measured native lanes are **far smaller than the seconds-long loading intervals**. They do not explain the reported scroll stall, and native aggregate timings cannot tell us whether the page's own JS or theme CSS is taking time inside the WebContent process.

## What the v7.627 probe failed to capture

- `webDocuments=[]`, even though four WKWebViews were enrolled and three JS injection attempts reported zero errors.
- No DOMInteractive / DOMContentLoaded / load end timings, web long tasks, resource timings, RAF intervals or input-to-scroll time.
- The session stopped on background after 35.7s, before its nominal 90s deadline.

## v7.628 diagnostic remediation

- While explicitly armed, send tiny cumulative WebKit aggregate **snapshots every 5s**. Do not depend on an evaluation callback after iOS has backgrounded/suspended WebKit.
- Collect **touchmove-to-first-scroll** and **touchstart-to-first-scroll** proxy timings, plus counts of gestures started and followed by a scroll.
- Deduplicate cumulative snapshots by an opaque numeric page key **in the offline report**, so WebKit totals are not added repeatedly.
- Retain the existing native timing lanes and loading intervals; show them alongside any successful WebKit reports.
- No production DOM walker, MutationObserver, recurring scanner, visual paint or Home raster change.

**Status:** Actual scroll-lag **cause remains unproven** in this TAR. The v7.628 source improves capture completeness and attribution, rather than guessing a UI-changing performance workaround. A 90-second foreground capture (with Search→PDP and attempted scrolls) is required for the next decision. A same-workflow run with AmazonDark disabled, if practical, would isolate Amazon/WebKit baseline from tweak cost.

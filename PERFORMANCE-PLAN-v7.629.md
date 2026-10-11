# AmazonDark v7.629 — performance diagnostic correction and A/B procedure

## Current evidence (from the user's v7.628 TAR)
- Search Results WKWebView `loading` interval: **19.53 seconds**.
- Product Details WKWebView `loading` interval: **18.05 seconds**.
- Maximum native main-loop gap: **1,003.85 ms**; maximum touch event age: **932.23 ms**.
- Web document reports: **0**, because the collector refused to inject JavaScript while `WKWebView.loading == YES` and delayed its first scheduled snapshot for 5 seconds.
- These are real timing observations, but `loading==YES` is **not** proof that scrolling was blocked for 19 seconds, and the source of the stalls is not yet identified.

## Implemented v7.629 diagnostic changes
1. Remove the WebKit-loading exclusion from the *opt-in performance recorder*. Instrumentation can start while the page is loading, and retries once at load completion. No change to production WebKit theming, media behavior or CSS.
2. Request one immediate small numeric aggregate snapshot at successful JS installation, while retaining 5-second bounded snapshots and the existing active-session deadline. Historical JS regression fixtures still run unmodified (the native caller explicitly requests the initial snapshot).
3. Record bounded per-evaluation timings: native monotonic request offset, completion latency, success/error flag, and whether the WebView was loading when requested. Even if the JS document is unresponsive, the evaluation completion time is a useful diagnostic.
4. Record whether the theme was **enabled when the recorder was armed**, and permit recording while the theme is disabled. This enables controlled A/B comparisons with the same device and identical browsing steps.
5. Offline report now displays injection callback delays, load-phase coverage and approximate matching of native WebView loading intervals to Search/PDP controller appearances. It labels this route mapping as a heuristic, not proven attribution.

## What has NOT been established
- We have **not** established whether Amazon's own scripting, network requests, WebKit contention, injected theme CSS, or native code causes the input stalls.
- This is a **diagnostic correction, not a lag fix**. Do not remove theming logic without proof of a hotspot.
- WKWebView evaluateJavaScript while loading may still run late or be replaced by navigation; the recorder now reports whether such attempts are delayed. If zero WebKit documents persist, an instrumented document-start installation would be the next escalation, not speculative CSS removal.

## Two short, comparable phone-side trials
**Trial A (theme ON):** install this build, ensure AmazonDark enabled; relaunch Amazon; arm PERFORMANCE; open the same Search query, attempt scroll during lag, open the same PDP, attempt scroll; allow 90s or export after an early background if necessary.

**Trial B (theme OFF):** disable AmazonDark from its own preferences (leave the tweak installed so the performance probe still runs), force close/relaunch Amazon, arm PERFORMANCE; repeat *identical steps* and export. Re-enable AmazonDark afterwards. If there is no functioning theme-disable switch, avoid ad-hoc process injection or uninstalling the tweak; instead send the ON capture first and report that a clean OFF control is unavailable.

Upload both TARs. Compare **native input/event gaps, WebKit navigation timings, long tasks, scroll-from-touch/move delay and injection-evaluation latency**; use the control to decide whether to optimize AmazonDark or investigate Amazon/WebKit/network first.

# v7.630 — performance recorder WebKit delivery repair

In v7.629, seven successful `WKWebView evaluateJavaScript` callbacks yielded zero WebKit documents because native code did not inspect the JavaScript return value. WebKit bridge postMessage errors were silently caught. This made successful evaluation appear like successful instrumentation without evidence.

v7.630 returns the numeric initial snapshot from `snapshotInitial()` through the `evaluateJavaScript` completion. Its native handler now routes that data through the same schema-safe aggregate sanitizer as WKScriptMessageHandler, and counts eval acks, evals without usable reports, and bridge messages separately. The JS result flags a message bridge failure when postMessage throws. The offline report includes the handshake counts and chooses each document's largest cumulative time, not whichever callback arrives last.

No changes to UI rendering or page scrolling. This is a diagnostic reliability fix, not a demonstrated input-lag fix. Missing metrics continue to be explicitly reported as missing.

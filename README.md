# AmazonDark v7.0.55~probe

Built directly from the v7.0.54 source, with two targeted corrections only.

## Sponsored glyph persistence
- Restores the v7.0.50 exact computed-color painter: Sponsored text remains Amazon-owned; only the stock info glyph is recolored.
- v7.0.53/54 watched only inserted child nodes. Amazon can rehydrate the same glyph by changing its existing `class`/`style`, so no child insertion occurs and the glyph falls back dark.
- v7.0.55 removes that document-wide child-list observer.
- Each discovered Sponsor feedback row gets its own tiny observer limited to that row and only `childList`, `class`, and `style` changes.
- The observer disconnects while repainting, preventing self-trigger loops. It then reapplies the exact current computed Sponsored-label color to a replaced or restyled glyph.
- No Sponsored text color is hard-coded or written.

## Chevron probe correction
The v7.0.54 report proved native touch coordinates were captured but the Web dump came from the wrong/late Web context (`NO_WEB_TAP_CAPTURE` plus a blank `body/html` grid).

v7.0.55 therefore:
- captures `UITouch.view` and its ancestor chain **before** `%orig`, before UIKit can clear the touch view;
- walks that actual touched view's superviews to obtain the exact `WKWebView` that received the tap;
- stores that exact WebView for the delayed dump instead of choosing an arbitrary tracked visible WebView;
- maps the native touch coordinate into that WebView and asks the live page for `elementFromPoint` / `elementsFromPoint` evidence directly;
- still retains the all-frame event tracer, so child-frame capture can supplement the native-point capture when available;
- captures the opened menu at +650 ms and writes automatically at +950 ms.

No PID, SIGUSR, terminal arming, pgrep, notifyutil, or recurring scan is used.

Probe output: `AmazonDark-chevron-tap-probe-7055.txt`.

## Performance character
- Production document-wide MutationObserver: 0.
- New Sponsor observers are scoped only to already-discovered Sponsor feedback rows.
- No TreeWalker, scroll listener, setInterval, or requestAnimationFrame loop.
- Chevron diagnostic work runs only on actual touches and is removed in the next clean production build.

GitHub Actions remains the authoritative Theos compile/link/package proof after push.

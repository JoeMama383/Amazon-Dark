# AmazonDark v6.0.184~probe — Buy Again refresh borders + Interests gradient

## v6.0.184 corrections

- Keeps the v6.0.183 Buy Again carousel-wide #494D4D border owner and v6.0.180 Buy Again TWB fix.
- Fixes a refresh/reconciliation lifetime bug: React can remove the tweak-owned CAShapeLayer from the host's sublayer array while the associated-object pointer remains non-nil. The owner now reattaches that same outline whenever its superlayer is no longer the card layer.
- The retained Buy Again probe now reports `attached=1/0` separately from `outline=1/0` so a future detached-overlay failure is immediately visible.
- Restores the historical v6.0.177 semantic Interests gradient owner for the wide/shallow white-gray-black strip beside "You're all caught up!".
- Native CAGradientLayer / BVLinearGradientLayer handling is phrase + geometry gated and clears only the matching transient gradient.
- WebKit handling reuses the existing bounded contrast traversal; no new MutationObserver, timer, scroll listener, interval, RAF loop, or window-wide recurring scan is added.
- Existing v6.0.179 `[class*=_bW9ia_suggestion_]` Related Interests card gradient removal remains unchanged.
- Existing Cart foreground recovery, Shop by brand repair, warm WebView preservation, JIT/120 Hz, TWB, Sponsored, symbols, splash, video and voice behavior are otherwise unchanged.

## Probe

`AmazonDark-buyagain-probe-6180.txt` remains the output file. After testing a refresh, a healthy claimed card should report `marked=1 outline=1 attached=1 contents=none`.

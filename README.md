# AmazonDark v7.0.52~probe

Built directly from the v7.0.50 visual base. v7.0.51 is abandoned and is not part of this source lineage.

## Production behavior retained
- Sponsored text remains Amazon-owned.
- AmazonDark paints only the adjacent Sponsored info glyph, dynamically matching the label's rendered computed color.
- v7.0.49/v7.0.50 chevron CSS attempts remain unchanged so the diagnostic observes the real still-dark chevron.
- Gray borders, standalone-ad OLED background/text behavior, scrollbar styling, TWB, 120 Hz, JIT, launch cover, bottom navigation and unrelated theming remain unchanged.

## v7.0.52 automatic chevron probe
There is no PID lookup, SIGUSR2, ps, awk, pgrep, notifyutil, terminal arming, Darwin relay or SpringBoard relay.

The probe is installed at document start in all frames and remains idle until a real user tap occurs. Each completed Amazon tap replaces the previous diagnostic candidate. A 350 ms de-dupe prevents the normal touchend/pointerup/click sequence from triple-capturing one physical tap.

For the latest tap it records the exact DOM event target, bounded outerHTML, composed event path, ancestors, hit-test stack, computed painter state, post-tap states at 0/80/250/650 ms, a bounded visible viewport grid at +650 ms, child-frame reports, the native touched UIView chain, and one bounded visible UIKit snapshot at +650 ms.

At +950 ms after the latest tap, the report is automatically serialized to:
`AmazonDark-chevron-tap-probe-7052.txt`

Test workflow: navigate to the failing dark chevron, tap it, leave the opened menu visible for about 2 seconds, background Amazon once, then run the supplied export command.

## Runtime character
Production paint remains free of MutationObservers, TreeWalkers, scroll listeners, intervals and RAF loops. The probe adds no recurring timer or scanner. Diagnostic work runs only in response to actual taps, and only the most recent tap is allowed to complete its delayed native dump.

GitHub Actions remains the authoritative Theos compile/link/package proof after push.

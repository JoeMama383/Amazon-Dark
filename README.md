# AmazonDark v6.0.111

## v6.0.111 — restore pre-first-frame Heart logic

- Production source is rebuilt from v6.0.104 for the Heart path, restoring the exact Heart handling that existed before the v6.0.105–v6.0.110 first-frame experiments.
- Removes the later synthetic/stable-shell Heart painter, descendant suppression, `heart6105` runtime short-circuit, forced Heart sizing, and selected-state CSS override.
- Restores Amazon's original/native Heart state behavior as handled by the v6.0.104 symbol pipeline, including the stock filled/unfilled transition when the Heart is tapped.
- Keeps the two-cards control from v6.0.110 untouched: 35x35 host, 24x24 canonical cards glyph, first-frame child suppression, and the current `translateY(-5px)` alignment.
- No new observers, scroll listeners, recurring timers, RAF loops, `dispatch_after` calls, or image-sampling work.

# AmazonDark v7.403 — Product Share sheet + probe control

Direct parent: `7.402~payment-first-paint-switcher-fix`.

v7.403 completes the Product-page SSF “Share this product with friends” sheet by reusing the already-proven Cart Share renderer contract instead of creating a second share implementation. Floors become OLED, neutral copy becomes light, the preview edge becomes standard gray, the product/share imagery enters the existing configured TWB lane, and authored blue/brand/star colors remain intact. Neutral pressed states stay dark.

A new **Hide Share Sheet for Probes** setting (default off; respring required) hides this exact SSF sheet/lightbox while testing, allowing screenshot-triggered FULL UI probes to scan the menu underneath. Manual sharing is also hidden while the testing switch is enabled.

The universal FULL, VIEWPORT and transition probes are regenerated as v7.403. See `COMMANDS.md`.

No new observer, polling loop, interval, RAF loop, Web scroll listener, recurring hierarchy scanner, or WKUserScript family is added.

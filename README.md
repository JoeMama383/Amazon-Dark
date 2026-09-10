# AmazonDark v7.391 — UI completion audit fix

Direct parent: `7.390~checkout-ui-completion`.

This is a probe-audit hardening pass over the seven Sep. 10 checkout/support surfaces and the
Subscribe & Save loading transition introduced in v7.390. It retains every v7.390 target plus the
v7.389 Subscribe-sheet and checkout app-switcher fixes.

A second element-by-element comparison against all eight FULL captures found three residual paint
owners that v7.390 did not fully claim: the top Help page heading, direct text nodes inside both
Maple banner text containers, and the delivery-address break/divider painters. v7.391 closes only
those gaps. The Help heading becomes light without touching the search/logo/orange greeting; Maple
neutral direct copy becomes light while authored blue links remain blue; and the address divider
loses its stock gradient/white `or` backing and uses the standard `#747a7c` divider on OLED.

All v7.390 payment-card, gift-options, carbon sheet, Subscribe loader, recurrence, address-button,
checkout Maple image/TWB, dynamic-color, radio/checkbox/switch and selection-state rules remain
unchanged.

No MutationObserver, interval, RAF loop, scroll listener, polling loop, recurring hierarchy scan,
additional WKUserScript, or generic app-switcher painter is added.

See `AUDIT-v7.391.md` and `COMMANDS.md`.

# v7.520 — FULL route-contract repair + Hamburger deep scan

## CI failure fixed

v7.519 prefixed the legacy route line with `personExact=0`, which removed the exact historical `FULL_ROUTE_POLICY pdpDetected=` contract asserted by `test_v7450_pdp_readonly_full.py`. v7.520 restores that prefix on every FULL route instead of weakening/removing the historical regression.

## Hamburger FULL scan

Historical Menu evidence proves the active native chain is `RCTScrollView#scrolled-hamburger -> RCTCustomScrollView`. v7.520 gives a currently visible exact Hamburger wrapper a dedicated finite FULL route before PDP detection. The probe moves the actual `RCTCustomScrollView` non-animated, waits 300 ms for React hydration, records bounded snapshots at each step, and restores the original offset. It never changes `scrollEnabled`.

## Person FULL

The v7.519 exact `RCTScrollView#me` route is retained. Person and Hamburger are the only route-specific native dispatches; generic non-PDP and PDP behavior remain inherited.

## Device evidence

A Hamburger FULL capture should contain `MENU_FULL_ROUTE`, changing `MENU_FULL_MOVE` offsets, and `MENU_FULL_SCAN_END`. A Person FULL capture should continue to contain `PERSON_FULL_ROUTE`, changing `PERSON_FULL_MOVE` offsets, and `PERSON_FULL_SCAN_END`.

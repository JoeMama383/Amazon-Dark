# AmazonDark v7.560 validation

Evidence base:

- completed `AmazonDark-v7.556-ui-full-probe-20261003-135049-398-r1` from the exact Returns Center screen;
- captured remaining white owner: `div.a-box.a-alert.a-alert-success` at 396x116;
- captured inner white fill: `div.a-box-inner.a-alert-container` at 382x112;
- captured authored success styling: 2px green top/right/bottom border and 12px green left rail in `rgb(11,123,60)`.

Static contracts:

- only the exact ORC success-alert fill planes are changed to OLED black;
- alert heading/content/list copy is forced white;
- v7.560 writes no border, border-color, radius, width, height, position, margin, or transform on those owners, preserving Amazon's green rail/perimeter;
- the existing ORC page gate `#a-page:has(#orc-items-details-and-content-section)` remains the route boundary;
- links and semantic colors retain currentColor behavior;
- v7.559 order-item OLED/count geometry and v7.558 Filters + universal probe repair remain intact;
- no MutationObserver, recurring timer, RAF, scroll listener, polling loop, setTimeout lane, or production traversal is added.

Final verification (2026-10-03):

- `tests/test_v7560_returns_success_alert_oled.py`: PASS;
- normalized repository regression set: 214/214 PASS in eight chunks (27 + 27 + 27 + 27 + 27 + 27 + 27 + 25), zero failures;
- `scripts/lint-logos.sh`: PASS;
- `scripts/ui-probe.sh`, `scripts/skeleton-probe.sh`, and `layout/DEBIAN/postinst`: shell syntax PASS;
- current package/runtime/FULL/VIEWPORT/TRANSITION/PDP probe identities synchronized to v7.560;
- monolithic `scripts/validate.sh` exceeded the local 120-second command window after progressing through passing historical regressions, so its normalized Python set was completed separately as listed above.

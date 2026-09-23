# AmazonDark v7.465 — PDP ad/book CI compatibility fix

Direct parent: **v7.464~pdp-ad-book-polish**.

v7.464's production visual changes are preserved. This build fixes the strict-regression failure caused by accidentally deleting the long-standing `// One immutable document-start program...` source sentinel immediately after `ADAddressManagementJS7412()`.

That sentinel is intentionally consumed by multiple historical regression tests as the stable end boundary for older WebKit program blocks. Its removal did not itself change runtime theming, but it made strict CI unable to slice those historical blocks and stopped validation at `test_v7412_address_location_aux_theme.py`. v7.465 restores the exact two-line sentinel in its historical location and adds a regression that locks the boundary in place.

The v7.464 PDP fixes remain unchanged in behavior: top standalone-ad header/floor ownership, Books divider, Book-details fade/text, Customer-review text, half-carousel OLED/text controls, BTF duplicate-border removal, and all-frame delivery remain intact. No MutationObserver, polling, RAF loop, Web scroll listener, or recurring DOM walk is added.

FULL, VIEWPORT, and TRANSITION identities are regenerated as v7.465 and remain separate workflows.

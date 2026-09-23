# AmazonDark v7.468 — PDP ad/book CI reconciliation

Direct parent: **v7.467~pdp-ad-book-strict-repair**.

v7.467 cleared the v7.448 performance-consolidation regression but exposed the next frozen contract in `test_v7454_carousel_probe_order.py`: the v7.454 device evidence explicitly requires the grid-carousel arrow controls and media to remain untouched. v7.464 had accidentally added a `.swiper-button-prev/.swiper-button-next` repaint and its new regression required that repaint, creating a direct contradiction between the old and new test contracts.

v7.468 resolves the contradiction in favor of the probe-backed v7.454 ownership rule. The half-carousel still gets the requested OLED structural floors, gray borders, white neutral text, white price/currency text, and transparent neutral sub-shells; the already-correct arrow controls and media are no longer restyled. `test_v7464_pdp_ad_book_polish.py` is corrected to require the arrows to remain untouched, and `test_v7468_ci_contract_reconcile.py` locks both sides of that contract together.

All v7.464 UI work remains intact: top standalone-ad header/floor treatment, gray Books divider, transparent Book-details fade, white Book-details/review copy, OLED half-carousel treatment, BTF duplicate-border removal, and document-start all-frame PDP delivery. The v7.465/v7.466/v7.467 historical slicing and performance compatibility repairs also remain intact.

No MutationObserver, polling loop, requestAnimationFrame loop, Web scroll listener, recurring DOM traversal, or new recurring native hierarchy work is added.

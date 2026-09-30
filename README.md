## v7.532 — Interests historical regression restore

Direct parent: v7.531.

v7.532 fixes the CI failure caused by v7.531 omitting `tests/test_v7529_interests_header_product_text_fix.py` from the clean source archive and dropping the exact v7.529 contextual-menu/product-text selectors that an existing repository correctly retained. The v7.530 visual follow-up remains intact.

The established existing-clone push workflow and separate FULL / VIEWPORT / TRANSITION command contract are unchanged.

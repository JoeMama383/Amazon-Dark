# v7.641 validation

## Completed compatibility checks

- Execute the 50 production JavaScript payloads with the old and new scope helpers in local Playwright WebKit. Compare a 220-tile progressive-loading product fixture on both Search and product routes. Sampled text color, background, border, image filter and geometry remain equal.
- Compare 60 nodes in normal and focused states on ten routes: Search, product, Home, Interests, Live, Cart, thank-you, Orders, Addresses and Returns. Fixture controls include add-to-cart, progress tracks, product/aisle images, semantic colors, review filter controls, Create List, sharing, shipping and a map. Their computed paint/geometry remain equal. The eight non-hot routes retain complete stylesheet contents, apart from version comments.
- New executable regressions cover selector boundary negatives, shared/mixed rules, complete-sheet hot-route omission and full source retention on other routes/child frames. Existing head-replacement recovery coverage remains.
- Offline report regression covers out-of-order cumulative snapshots, independent document IDs, ambiguous child-frame/WebView time origins, missing values and separate Search/product results.

## Progressive-loading timing observations

Each run installs the production payloads into an initially empty document, then appends 220 synthetic tiles in 22 batches, forcing layout after each batch. Order alternates v7.640, v7.641, v7.641, v7.640.

| Route | v7.640 batch totals | v7.641 batch totals | v7.640 worst batches | v7.641 worst batches |
| --- | --- | --- | --- | --- |
| Search | 607 / 510 ms | 465 / 355 ms | 41 / 28 ms | 31 / 19 ms |
| Product | 815 / 833 ms | 644 / 768 ms | 44 / 48 ms | 37 / 43 ms |

These are local WebKit fixture observations under variable host load, not iPhone results or a statistical benchmark. They support reducing irrelevant stylesheet work but do not establish that the remaining phone delay is fixed.

## Build validation

- Strict repository validation passed all **305 Python regression scripts**, source/JavaScript checks and Logos lint. The current-version handoff and all active probe identities are synchronized to v7.641. Existing whole-payload golden checks preserve authored theme code and CSS declarations apart from the explicitly audited composition changes and version labels.
- Logos generation and Clang ARM64/iOS 17 syntax checks passed for `Tweak.xm`, `AmazonDarkSB.xm`, `ADPrefsController.xm` and `ADSponsored.m`, using the iPhoneOS 16.5 SDK with its Cryptex WebKit headers. Five pre-existing opt-in UI-probe retain-cycle warnings remain; no new compiler errors. This is syntax checking, not linking or packaging.
- The final version-stamped production payloads were re-extracted and the ten-route WebKit compatibility comparison passed again.

GitHub Actions must still compile, link and package the DEB. No on-device result is claimed.

No private screenshot or probe capture is included in the source ZIP. `COMMANDS.md` contains the exact existing-clone push and normal performance, FULL, VIEWPORT and TRANSITION arm/export commands.

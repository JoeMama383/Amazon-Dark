# AmazonDark v7.415 — location text finalization fix

Direct parent: **v7.414~location-navigation-renderer-fix**.

The paired v7.414 FULL probes prove the intermittent dark location text is not a second renderer. The bad and good captures contain the same RCTTextView text hashes, geometry, and ancestry; only their final attributed foreground differs. The bad capture ends with stock neutral black/gray while the good capture ends light/white, and authored Amazon-blue link text is identical in both.

v7.415 closes the missing React Native final-commit path by owning `RCTTextView setTextStorage:contentFrame:descendantViews:` in addition to the existing one-argument setter. Neutral Nile/location text is normalized to white before React commits the storage and reasserted immediately afterward. Saturated semantic colors remain authored. No timer, polling loop, MutationObserver, RAF, scroll listener, recurring hierarchy scan, or new hook class is added.

All v7.414 floors/cards/ZIP/country-row handling and earlier theming remain inherited. FULL, VIEWPORT, and TRANSITION probe identities are regenerated to v7.415.

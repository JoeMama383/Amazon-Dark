## v7.551 — UI restoration + obsolete source-size gate removal

Direct parent: v7.546.

The v7.546 GitHub regression failure proved the release archive was built from a stale clean-tree baseline: the existing clone retained `test_v7546_webkit_editing_trait_repair.py`, but the v7.546 source ZIP overwrote `src/Tweak.xm` with a copy that no longer contained the `ADWebKeyboardStyle7546` implementation that regression expected. Because the phone workflow overlays the staged archive onto the existing clone, the test survived while its production implementation disappeared.

v7.551 keeps the retained WebKit editing-trait repair plus the v7.548 search-filter/App Settings work intact, and adds a focused About You memory-grid follow-up: white cards, pills, the import banner, and the Create/search controls are turned into OLED/gray containers, dark-on-dark headers inside those containers are forced legible, and dynamic blue selection/link accents are preserved. No production observers, timers, polling, or recurring hierarchy scans are introduced.

The independent v7.546 FULL Hamburger route-arbitration repair is retained unchanged: foreground Hamburger ownership still wins over retained Person surfaces and both `scrolled-hamburger` identities remain recognized.

v7.549: Filters sheet OLED floors, white neutral text and close icon, gray separators, OLED buttons with gray borders. Existing sprite artwork and control geometry retained.

v7.549: OLED loading floor for the probe-confirmed Home live-events hero card. Retains the latest keyboard merge and FULL menu routing repairs. See REVIEW-v7.549.md and VALIDATION-v7.549.md.

## v7.549 — WebKit editing-trait merge repair

Direct parent: v7.546.

The v7.546 GitHub regression failure proved the release archive was built from a stale clean-tree baseline: the existing clone retained `test_v7546_webkit_editing_trait_repair.py`, but the v7.546 source ZIP overwrote `src/Tweak.xm` with a copy that no longer contained the `ADWebKeyboardStyle7546` implementation that regression expected. Because the phone workflow overlays the staged archive onto the existing clone, the test survived while its production implementation disappeared.

v7.549 restores that WebKit editing-trait ownership instead of deleting or weakening the retained regression. Exact `WKContentView` editing now forces a Dark `overrideUserInterfaceStyle` before `becomeFirstResponder` reaches UIKit, re-primes the cached WebKit text-input traits, reasserts Dark when the active responder's trait collection changes, and restores the authored style after editing ends. No geometry, modal CSS, polling, timers, DOM walkers, or recurring keyboard hierarchy work are added.

The independent v7.546 FULL Hamburger route-arbitration repair is retained unchanged: foreground Hamburger ownership still wins over retained Person surfaces and both `scrolled-hamburger` identities remain recognized.

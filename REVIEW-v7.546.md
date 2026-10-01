# v7.546 — FULL menu route arbitration repair

Source diffing shows v7.542 through v7.545 did not change the dedicated FULL menu scanner itself; those releases only bumped its version strings while expanding the separate transition probe. The runtime failure is a latent route-arbitration defect from the v7.519/v7.520 dedicated native routes.

The dispatcher checked Person before Hamburger. Its visibility predicate only tests hidden/alpha/ancestor state plus screen intersection, so a retained `RCTScrollView#me` under an open React Hamburger overlay can still qualify. Once Person matches, the dispatcher returns and never evaluates Hamburger. The Hamburger detector was also narrower than production theming: it recognized only `RCTScrollView#scrolled-hamburger`, while production menu ownership already accepts `scrolled-hamburger-view` during hydration.

v7.546 makes foreground hit-test ownership authoritative, recognizes both known Hamburger root identities, resolves the real `RCTCustomScrollView`, and checks Menu before Person/PDP. The scan remains finite and restores Amazon's original offset without changing `scrollEnabled` or geometry.

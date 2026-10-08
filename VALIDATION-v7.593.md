# AmazonDark v7.593 validation

Source: `7.593~reviews-business-card-theme`

- New v7.593 review/card selector test: PASS
- Emitted JS parse with Node and CSS selector parser (base + media): PASS
- gnu++98 string-literal include compile: PASS
- Two v7.592 FULL probe TARs reviewed: **both partial**, not a verified complete FULL traversal; new source leaves the FULL scan path unchanged.
- Prime Business Card styling is screenshot-backed; exact owner/selector verification requires its own FULL or VIEWPORT capture after installation.

- Full validator-normalized Python regression corpus, run against the final source in bounded batches: **246/246 PASS** (82 + 82 + 82).
- Maintainer-script executable bit, current-version identity, lint-logos, shell helper syntax: PASS.
- Theos/GitHub Actions build and on-device visual behavior: not run from this environment; cannot claim installation success.

Passing regression tests do not constitute visual verification on an iPhone.

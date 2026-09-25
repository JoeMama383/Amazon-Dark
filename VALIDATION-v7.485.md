# AmazonDark v7.485 validation

## CI failure reproduced from packaged v7.484

Using the exact v7.484 source ZIP and the same temporary-test normalization logic as `scripts/validate.sh`, `test_v7363_search_related_cart_claimed.py` failed before Theos compilation. The normalized test expected:

`#define AD_VERSION "v7.484-home-hero-pill-owner-fix"`

while the actual v7.484 source correctly contained:

`#define AD_VERSION "v7.484-ci-build-repair-ui-followup"`

The v7.484 normalizer recognized package identity strings but failed to recognize escaped `#define AD_VERSION \"...\"` literals in Python regression source. It then globally replaced only the numeric version, leaving the stale slug behind.

## v7.485 repair

`scripts/validate.sh` now recognizes both escaped and unescaped AD_VERSION identity literals when determining the current handoff identity. The normalized v7.363 regression now expects the complete current v7.485 tag, not a current version number paired with a stale historical slug.

## Checks

- Exact previously failing `test_v7363_search_related_cart_claimed.py`: PASS after v7.485 normalization.
- Entire Python regression corpus: **162/162 PASS**, executed from a normalized temporary copy using the same v7.485 normalization logic, in two bounded parallel batches (110 + 52) with zero failures.
- `scripts/lint-logos.sh`: PASS.
- `sh -n scripts/ui-probe.sh`: PASS.
- `sh -n scripts/skeleton-probe.sh`: PASS.
- `sh -n scripts/validate.sh`: PASS.
- `tests/test_v7480_build_syntax_guard.py`: PASS, retaining the Objective-C++ syntax guard added after the v7.479 compiler failure.
- `tests/test_v7483_books_returns_followup.py`: PASS.
- `src/Tweak.xm`: 854,053 bytes, below the repository's 856,000-byte gate.

The current chat tool surface does not expose a callable GitHub repository/Actions connector, so this report does not claim direct access to the private live Actions log. The CI failure above was reproduced from the exact packaged v7.484 source instead of inferred from a partial validator run.

# AmazonDark v7.484 validation

## CI failure root cause carried forward from failed v7.483

The repository workflow runs `AD_STRICT_VALIDATE=1 sh scripts/validate.sh` before installing Theos or building the package. The failed v7.483 source contained recent regression tests that hard-coded the prior v7.482 package/probe/handoff identity while `scripts/validate.sh` only normalized the older v7.460 baseline. The failure is reproducible locally: `tests/test_v7482_pdp_immersive_review_profile_theme.py` rejects a newer package version before behavioral assertions are reached.

v7.484 changes the temporary-test normalizer so each test's current handoff identity is discovered and normalized to the current build while deliberately preserving lower historical/negative-control versions such as v7.415 receipts and v7.444 captures. This avoids the stale-version CI failure without weakening selector/behavior assertions.

## Checks performed on final v7.484 tree

- `bash scripts/lint-logos.sh`: PASS.
- `sh -n` on `scripts/ui-probe.sh`, `scripts/skeleton-probe.sh`, and `scripts/validate.sh`: PASS.
- `tests/test_v7480_build_syntax_guard.py`: PASS; exact Objective-C++ nested-message regression remains guarded.
- `tests/test_v7483_books_returns_followup.py`: PASS against v7.484.
- Current/handoff identity regression suite after the exact v7.484 CI normalization: 23/23 PASS, including `test_probe_embedding.py`, `test_probe_handoff.py`, v7.462-v7.482 current-identity tests, and the v7.484 follow-up test.
- `ADNewMenus7482.js.inc`: compiles as C99 and GNU++98 adjacent string literals; emitted JavaScript parses with `node --check`.
- `ADReturnsTheme7480.js.inc`: compiles as C99 and GNU++98 adjacent string literals; emitted JavaScript parses with `node --check`.
- `src/Tweak.xm`: 854,052 bytes, below the repository's 856,000-byte regression gate.

## Limitation

A complete Theos/iOS SDK package compile cannot be performed in this Linux container because the repository CI installs Theos and the patched iOS 16.5 SDK on a macOS runner. GitHub Actions remains the final package-link confirmation. The exact validation defect that made v7.483 fail before the Theos build step has been reproduced and corrected here.

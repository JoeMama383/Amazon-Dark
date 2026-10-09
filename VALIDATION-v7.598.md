# AmazonDark v7.598 corrected source validation

The first v7.598 ZIP contained stale v7.597 probe/export version markers. This halted `scripts/validate.sh` on `scripts/ui-probe.sh` before the `git add`, `git commit` and `git push` steps in the `set -eu` phone handoff. Corrected all runtime/probe identities and native capture filenames to v7.598, retaining the v7.598 UI changes.

`AD_STRICT_VALIDATE=1 sh scripts/validate.sh`: PASS; lint-logos OK; 253 Python regressions PASS, including native compile/syntax, JS parsing, probe contracts, source version synchronization and the new v7.598 focused tests. Device build and actual UI verification are not claimed.

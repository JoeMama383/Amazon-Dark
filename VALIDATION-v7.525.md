# AmazonDark v7.525 validation

Release: `7.525~returns-thumbnail-handoff-regression-repair`
Direct parent: `7.524~returns-thumbnail-render-geometry-revert`

## Regression repaired

v7.524 accidentally replaced the established existing-clone push workflow and frozen probe command syntax in `COMMANDS.md`. CI correctly rejected it at `test_v7478_home_pdp_six_fix.py` because the handoff no longer contained `export full`, `export viewport`, and `skeleton-probe.sh export`.

v7.525 restores the v7.523-proven command contract while preserving the v7.524 Returns thumbnail/border/text implementation unchanged.

## Source regressions

The same version-normalization logic used by `scripts/validate.sh` was applied to a temporary regression copy. All **179/179** `tests/test_*.py` regressions passed when executed in bounded batches, including:

- `test_v7478_home_pdp_six_fix.py` — the exact CI failure from v7.524;
- all handoff/COMMANDS regressions from v7.375 through v7.525;
- all probe identity, FULL/VIEWPORT/TRANSITION, PDP, Person, Returns, keyboard, checkout, Search, Cart, and performance regressions;
- new `test_v7525_handoff_contract_repair.py`, which rejects `git init`, `.git` deletion, force-push, and the unsupported shorthand probe commands.

The exact sequential `AD_STRICT_VALIDATE=1 sh scripts/validate.sh` wrapper exceeds this environment's single-command execution window, so it is not falsely reported as an end-to-end wrapper PASS. Its normalized Python regression set was instead run completely in batches.

## Static validation

PASS:

- `layout/DEBIAN/postinst` mode 755;
- `scripts/lint-logos.sh`;
- shell syntax for validate/UI/transition helpers;
- current-version synchronization across package, native runtime, FULL/VIEWPORT JS, transition helper, and SpringBoard probe identity;
- stale superseded regression guard;
- no `git init`, `.git` deletion, `git push -uf`, or unsupported `ui-probe.sh full` / `viewport-arm` / `viewport-export` in `COMMANDS.md`;
- established `export full`, separate VIEWPORT arm/export, and separate TRANSITION arm/export contract present.

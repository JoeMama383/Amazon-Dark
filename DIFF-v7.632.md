# AmazonDark v7.632 — CI handoff validation repair

## Cause of GitHub Actions failure
The frozen `tests/test_v7375_checkout_prepaint_snapshot_hydration.py` asserts that `COMMANDS.md` contains the exact shell substring `sh scripts/validate.sh`. The v7.631 handoff omitted validation from its phone push instructions. This is an actual handoff-contract regression, not an error in the Search/PDP fast-path code. The full strict job stopped at that assertion, before it could compile the .deb.

## Repair
- Restore `AD_STRICT_VALIDATE=0 sh scripts/validate.sh` to the existing-clone push documentation before staging/committing.
- Add `tests/test_v7632_handoff_validate_ci_contract.py` to guard the validation and separated probe commands.
- Synchronize package and probe identity to v7.632.
- Retain all v7.631 Search/PDP fast-path and performance-probe logic unchanged other than version-label updates. No UI styling, Home raster, image-taming, geometry, or scanner algorithms changed.

## Exact failed regression
Normalized v7.375 fixture: PASS. The already existing v7.439, v7.525, and v7.531 handoff contracts: PASS.

## Scope
This is a CI/documentation compatibility fix. It does **not** establish a speedup or resolve the user-reported lag. The last production performance change is still the v7.631 Search/PDP checkout-style fast path, pending device measurements.

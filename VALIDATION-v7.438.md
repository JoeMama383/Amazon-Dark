# AmazonDark v7.438 validation

- Exact source parent: v7.437 `pdp-standalone-ad-treatment`.
- Clang/Objective-C string compile regression for the sponsored-search rail selector: PASS.
- Checkout TWB format conversion/argument count regression: PASS (8 conversions / 8 arguments).
- Strict handoff contract regression (`test_v7375_checkout_prepaint_snapshot_hydration.py`): PASS after restoring `sh scripts/validate.sh` to `COMMANDS.md`.
- v7.387 optimization/probe golden normalization: PASS after normalizing the current v7.438 probe version back to the v7.433 golden identity.
- `test_probe_handoff.py`: PASS.
- Full production Python regression inventory: 120 scripts accounted for; 118 passed in the bounded parallel pass, the two remaining/failed strict cases were rerun after correction and both PASS.
- `scripts/lint-logos.sh`: PASS.
- UI/skeleton shell syntax: PASS.
- Full Theos compile/link remains GitHub/device proof; the source-level compiler blocker reported at `Tweak.xm:809` is corrected.

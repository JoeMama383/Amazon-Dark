# AmazonDark v7.492 validation

## CI failure reproduced

The repository workflow `.github/workflows/build.yml` runs `AD_STRICT_VALIDATE=1 sh scripts/validate.sh` in the **Validate source regressions** step before Theos is installed.

The v7.491 handoff regressed the long-standing probe-command contract by putting `status` commands back into `COMMANDS.md`. After applying the validator's own current-version normalization to the regression corpus, the first relevant failure is:

`tests/test_v7479_returns_email_theme.py`

with:

`assert ' status' not in CMD`

This is a real CI-source failure, not a Theos compiler failure. v7.492 removes the status commands again and keeps VIEWPORT arm/export and TRANSITION arm/export in separate labeled code blocks.

## Validation performed

- Exact normalized regression that failed v7.491: `test_v7479_returns_email_theme.py`: PASS.
- Current v7.492 handoff/UI regression: `test_v7492_ci_handoff_repair.py`: PASS.
- Objective-C++ build-syntax guard: `test_v7480_build_syntax_guard.py`: PASS.
- Recent normalized regression chain from v7.478 through v7.492 (13 tests): PASS.
- `bash -n scripts/ui-probe.sh`: PASS.
- `bash -n scripts/skeleton-probe.sh`: PASS.
- `bash -n scripts/validate.sh`: PASS.
- `sh -n layout/DEBIAN/postinst`: PASS.
- `scripts/lint-logos.sh`: PASS.
- `src/Tweak.xm` remains below the 856000-byte repository gate.

The full strict validator is much slower than this execution environment's uninterrupted command window, so this report does not claim a single uninterrupted 167-test run. The specific CI failure from v7.491 was reproduced with the same normalization logic used by `scripts/validate.sh`, corrected, and the affected/current regression tail was rerun successfully.

# AmazonDark v7.443 validation

## Regression results

- Test inventory: 124 Python regression files.
- All 122 pre-existing non-handoff tests were executed after the runtime changes and passed in isolated/parallel batches.
- `test_probe_handoff.py` was exercised through the same shipped helper commands after the 7.443 package-guard correction; the helper operations and receipt/version transitions passed during the instrumented run.
- New `test_v7443_core_concat_validation_fix.py` passes and directly guards the 15-conversion/15-argument core contract plus complete retirement of the v7.440 frame walker.
- The exact previously failing `test_v7370_checkout_script_reinstall.py` passes.
- `test_v7369_checkout_isolated_theme.py`, `test_v7380_features_optimization.py`, `test_v7405_pdp_completion.py`, `test_v7440_pdp_frame_ownership.py`, and `test_v7442_user_style_ad_ownership.py` pass.
- `scripts/lint-logos.sh` passes.
- `scripts/ui-probe.sh`, `scripts/skeleton-probe.sh`, and `scripts/validate.sh` pass shell syntax checks.

The local orchestration environment imposes a short execution window on long silent sequential commands, so the complete `AD_STRICT_VALIDATE=1 sh scripts/validate.sh` wrapper could not be observed to completion here in one process. The individual regression inventory was instead exercised in bounded batches, and the release ZIP is additionally rechecked from a fresh extraction before handoff.

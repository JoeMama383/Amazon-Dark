# AmazonDark v7.579 validation

Package: `7.579~prime-refinement-paint-only`
AD_VERSION: `v7.579-prime-refinement-paint-only`

## Regression sources

The complete normalized Python regression source set was executed against the final v7.579 tree in four bounded batches to avoid the execution-environment timeout masking the result:

- Batch 1: 58 / 58 PASS
- Batch 2: 58 / 58 PASS
- Batch 3: 58 / 58 PASS
- Batch 4: 58 / 58 PASS
- Total: **232 / 232 PASS**

Additional final-tree checks:

- `scripts/lint-logos.sh`: PASS
- Version/probe identity checks: PASS
- normalized `test_v7448_performance_consolidation.py`: PASS
- normalized `test_v7574_capture_ui_completion.py`: PASS
- normalized `test_v7579_prime_refinement_paint_only.py`: PASS

The monolithic sequential `AD_STRICT_VALIDATE=1 sh scripts/validate.sh` was also started on the final v7.579 tree. Its source/version/lint/compile prechecks and early regressions passed, but the execution container terminated the sequential run on elapsed-time limits. It is therefore not counted as a complete pass. The full normalized regression corpus was then executed in bounded batches above, with every regression source passing.

## v7.579 geometry regression guard

`test_v7579_prime_refinement_paint_only.py` freezes the Prime Deals refinement-sheet implementation as paint-only. Within that family it rejects synthesized:

- `border:1px` / `border:2px`
- border-side geometry (`border-top`, `border-bottom`, etc.)
- `border-radius`
- `outline` / `outline-color`
- width / height / box-sizing geometry
- display geometry such as the prior `display:inline-flex`
- slider thumb/control ownership

The retained rules change only existing paint: OLED backgrounds, white text, existing border colors, gray divider paint, and the authored blue slider rail.

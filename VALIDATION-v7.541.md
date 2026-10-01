# v7.541 validation

## Build failure reproduced from source semantics
The only functional v7.539 -> v7.540 getter change placed `,next=...` after a bare Logos `%orig` on the same line. Logos treats a bare `%orig` replacement as extending through the rest of that source line, so the generated file loses that declaration. This directly explains the two compiler errors in the v7.540 Theos build.

## Repair
The original result assignment now ends at `%orig;`. The dark-clamp variable is declared on its own following line. Setter behavior remains `%orig(next)` and is unchanged.

## Regression added
`test_v7541_keyboard_logos_build_fix.py` requires the split-statement form and rejects a bare `%orig` followed by a comma on the same line inside the legacy-traits hook.

## Final validation performed
- `bash scripts/lint-logos.sh`: PASS, including the new bare-`%orig,` negative control.
- `sh -n scripts/ui-probe.sh`: PASS.
- `sh -n scripts/skeleton-probe.sh`: PASS.
- `tests/test_v7480_build_syntax_guard.py`: PASS.
- `tests/test_v7533_web_theme_payload_parse.py`: PASS.
- `tests/test_v7541_keyboard_logos_build_fix.py`: PASS.
- Exact `scripts/validate.sh` identity normalization reproduced in a temporary in-repo test copy: **197/197 `test_*.py` regressions PASS** across six bounded batches.
- The monolithic strict wrapper was also started and passed lint/version gates plus the early regression sequence, but exceeded this environment's single-process timeout; the exact normalized regression inventory it would execute was then completed in bounded batches as above.
- `src/Tweak.xm`: 855,928 bytes (<856,000-byte source-size gate).

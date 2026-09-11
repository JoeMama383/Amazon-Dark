# AmazonDark v7.392 probe handoff / strict-CI audit

## Base
- Direct parent: `7.391~ui-completion-audit-fix`.
- UI/theming contract: unchanged from v7.391.
- Trigger for this build: GitHub strict validation failure in `tests/test_probe_handoff.py` at the
  `arm launch` fallback case with `AD_PLUTIL_STYLE=unavailable`.

## Root cause
The v7.391 helper had two duplicated version-maintenance structures:

1. The receipt **candidate filename list** jumped from the current `$AD_PROBE_NAME` directly to
   v7.389, omitting v7.390.
2. The receipt payload version regex accepted only through v7.390, so the current
   `AmazonDark-v7.391-probe-status.json` was rejected even though its bundle/event were correct.

When the test removed the metadata plist and forced all `plutil` dialects to fail, those two defects
left the helper with zero verified Amazon containers. The failure was therefore real helper logic,
not a macOS runner issue and not a theming regression.

## Correction
- Replace the long explicit candidate list with one bounded receipt-family glob:
  `AmazonDark-v7.*-probe-status.json`.
- Derive the numeric version from the receipt filename.
- Require filename version to be numeric and inside the supported 344..399 compatibility window.
- Require payload bundle `com.amazon.Amazon`.
- Require payload event `PROBE_BOOTSTRAP`.
- Require the payload version prefix to match the filename version exactly.
- Use the same receipt-family glob for diagnostic reporting and export, preventing a second stale
  version list from dropping a valid status file.
- Apply the same filename/payload-consistency discovery rule to `scripts/ui-probe.sh`, whose explicit
  upgrade receipt list had also drifted behind current builds.

## Regression coverage
`tests/test_probe_handoff.py` now explicitly proves:
- current v7.392 receipt works when all `plutil` forms fail;
- v7.391 immediate-previous receipt works;
- v7.390 receipt works (the exact omission in v7.391);
- wrong bundle is rejected;
- Amazon-like receipt with filename/payload version mismatch is rejected;
- duplicate paths remain de-duplicated;
- viewport UI-probe current/upgrade receipt discovery and mismatch rejection remain correct;
- transition/launch arming, export, tar fallback and historical receipt compatibility still work.

## Runtime impact
None to normal Amazon rendering. The changed shell helper executes only when the user explicitly
runs `scripts/skeleton-probe.sh`. No production CSS/JS selector, TWB rule, native view classifier,
launch policy, SpringBoard snapshot policy or menu theming rule is changed.

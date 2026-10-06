# v7.567 validation

Baseline: origin/main 16df804e (v7.566).
Evidence: FULL 20261005-145328-488-r1 (store locator) and FULL 20261005-145433-640-r2 (native Health sheet), IMG_7507/7508.

Store probe: postal glyph #Shape stroke rgb(0,0,0); attribution button background rgba(255,255,255,.5); wrapper rgb(48,51,53). Correct the exact stroke and both background colors, preserving the information background-image.

Health probe: captured image remains 1029x243 in a 384x96 native image view, alpha 1. The screenshot shows brighter subtitle/glyph after v7.566, but dark teal title and a pale curved edge. Production raster policy previously skipped alpha below16. New pixel tests exercise low-alpha/pale cleanup, dark-cyan contrast, preserved bright cyan and unchanged alpha. This does not claim visual confirmation on-device; device verification remains required.

Validation: lint-logos OK; strict regressions OK (220), including exact native helper compiler checks and raster policy execution. Native Theos compilation remains pending.

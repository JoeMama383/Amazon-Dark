# AmazonDark v7.451 validation — PDP streaming FULL

Direct parent: `v7.450~pdp-readonly-full`.

## Required contracts

- PDP route/#dp classification remains narrow.
- PDP FULL contains no Web/native scroll mutation.
- PDP FULL contains one native start evaluation only; it does not use `ADUIEvalAppend7364` or `__adUIProbeContinue7446`.
- Page-side scan is finite, time-sliced and streamed through `WKScriptMessageHandler`.
- A second WeakSet-backed pass finds newly mounted nodes without scrolling.
- Non-PDP FULL remains v7.449 behavior.
- VIEWPORT, TRANSITION and TAR isolation remain inherited.
- Production recurring-work constraints remain inherited.

## Device evidence motivating this build

The failed v7.450 capture reached PDP read-only mode, passively grew to 14,175 px, emitted 199 tiny chunks but only 927 elements, then hit `WEB_TIMEOUT label=PDP_READONLY_FULL_DOM after=4.0s`. This build specifically removes that per-chunk native evaluation transport.

## Final-source results

- `bash scripts/lint-logos.sh`: PASS.
- `sh -n scripts/ui-probe.sh`: PASS.
- `sh -n scripts/skeleton-probe.sh`: PASS.
- `sh -n layout/DEBIAN/postinst`: PASS.
- `node --check` on the reconstructed `ADPDPMainStream7451.js.inc`: PASS.
- All **129/129** `tests/test_*.py` files: PASS in deterministic chunks, including `test_probe_handoff.py`.
- Targeted v7.448 performance, v7.449 FULL, v7.450 no-scroll and v7.451 streaming tests: PASS.
- `AD_STRICT_VALIDATE=1 sh scripts/validate.sh` advanced through the inherited production/cold-launch/UI contracts without a failure before the container execution cap stopped the monolithic process. The complete regression suite was therefore verified separately as above.

No on-device responsiveness claim is made until the installed Actions build is tested.

# AmazonDark v7.618 — validation status

## Confirmed from the actual uploaded compiler log

The two blocking errors in `amazondark-build.log` are:

- `src/Tweak.xm:4309:68`: undeclared identifier `ADMenuButtonFill7255`.
- `src/Tweak.xm:10348:8`: undeclared identifier `liveText`.

There is also a nonblocking `-Wformat-insufficient-args` warning at line 2675, corrected in v7.618.

## Local checks

- New source-level + isolated GNU++98 ObjC++ checker `tests/test_v7618_actual_compiler_diagnostics.py`: PASS.
- `scripts/lint-logos.sh`: PASS.
- Shell parser for all three probe scripts: PASS.
- Full strict `AD_STRICT_VALIDATE=1 sh scripts/validate.sh`: attempted locally twice; did not finish within the runtime limit. First attempt stopped at a historic COMMANDS contract, subsequently corrected. Second run reached the v7.388 tests before timeout, with no observed failing assertions at that point. **Not a full-suite pass claim.**
- Focused normalized historical regression run: **19/19 PASS**, covering v7.603–v7.618 plus v7.392 and v7.416 probe/CI contracts.
- Probe helper shell syntax (`sh -n` for UI, skeleton and performance): PASS.

## Not tested in this environment

- Theos/iOS SDK full native build.
- Actual Amazon on-device UI or probe capture.

ARC retain-cycle warnings in the scanner are not the reported compiler errors and are untouched in this narrow compilation repair.

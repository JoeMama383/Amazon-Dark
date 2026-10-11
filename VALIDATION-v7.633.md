# v7.633 validation results

## Reproduced CI failure
`tests/test_v7596_web_cache.py` failed in v7.632 because it extracts a portable C++98 cache-guard function; the Search/PDP checkout route gate introduced Foundation `NSString` declarations inside that extracted region. The original diagnostic only printed `CalledProcessError`. Reproduction with compiler stderr exposed four errors: unknown `NSString` twice, Objective-C `@` expression, and invalid bracket syntax in pure C++.

## Fix
The real checkout-only route gate is unchanged and executes in the Objective-C++ Logos tweak build. `#if defined(__OBJC__)` restricts native NSString use to actual Objective-C++, while the test harness sees an inert `long program` that is replaced by the pre-existing gnu++98 fixture. There is one production WKUserScript assignment, and no duplicate cache rebuild or runtime wrapper. All checkout JavaScript payloads are unchanged.

## Completed local checks
- `python3 tests/test_v7596_web_cache.py`: PASS, actual C++98 compiled and executed.
- `python3 tests/test_v7631_search_pdp_fastpath_and_perf_pull.py`: PASS, Search/PDP checkout gate remains active.
- `python3 tests/test_v7633_web_cache_cpp98_compat.py`: PASS, exercises both original tests and checks correct compile-mode separation.
- Recent normalized tests v7.596 through v7.633: 44/44 PASS (see separate log).
- Additional historical tests v7.440 through v7.595: 99 PASS before execution-window limit, no reported failures (see separate log).
- `bash scripts/lint-logos.sh`: PASS.
- `bash -n` on three probe helpers: PASS.
- Python test sources compile: PASS.
- Versioned source identity, ZIP integrity: verified.

## Not verified
- Full strict validation was attempted but did not complete an uninterrupted run in this environment.
- Full Theos/iOS compilation and on-device performance are not available locally.
- This is an isolated CI compatibility fix; it does **not** establish that Search/PDP input latency is resolved.

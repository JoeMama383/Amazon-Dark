# AmazonDark v7.437 validation

- Exact source parent: PASS (`AmazonDark-v7.436-search-sponsored-rails-fix-source.zip`).
- Dedicated v7.437 PDP standalone-ad regression: PASS.
- v7.432 SafeFrame regression updated for the intentional v7.437 raster-taming extension: PASS.
- v7.433 universal cross-frame probe regression: PASS.
- v7.436 Search sponsored-rail regression: PASS.
- PDP emitted-JavaScript execution/repeat-injection regression: PASS.
- All 119 `tests/test_*.py` production regression scripts: PASS. The long probe-handoff suite was rerun independently and passed after a parallel-run timeout.
- Four shared helper/delta Python scripts also pass. `_dbg_probe.py` is an ad-hoc debug fixture, not part of `scripts/validate.sh`, and fails unchanged in the exact v7.436 parent because it intentionally supplies an old installed-package fixture.
- `sh -n scripts/ui-probe.sh`: PASS.
- `sh -n scripts/skeleton-probe.sh`: PASS.
- `scripts/lint-logos.sh`: PASS.
- SafeFrame emitted JavaScript parses under Node: PASS.
- No new MutationObserver, polling interval, RAF loop, Web scroll listener, or recurring hierarchy scan.
- Full Theos compile/link is unavailable in this container; GitHub Actions/device build remains compile/link proof.
- Device visual validation: pending v7.437 installation.

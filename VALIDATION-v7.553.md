# v7.553 validation

- Direct source baseline reconstructed from v7.550.
- Search Filters sheet uses the v7.548 FULL-r3 probe owners: `#dropdown-content-s-all-filters`, `.sf-filters-vtabs-tabs-container`, `.s-vtabs-contents-container`, `.sf-bottom-nav.sf-bottom-nav-current`, and `.sf-show-results`.
- Right-side filter option containers: medium gray `#303335`, standard gray `#747a7c` border, white text.
- Left Filters rail: subtle dark-gray tint plus one continuous right divider `#494d4d`; selected blue accent is not overwritten.
- Sticky footer: authored top/bottom divider borders and pseudo-divider paint are removed.
- Show-results control: OLED black, white text, real 1 px `#747a7c` border, no yellow fill/shadow.
- Retired every active historical numeric `Tweak.xm` source-size assertion inherited by v7.550; no active `856000` / `len(S|T.encode()) < N` source-size gate remains.
- Repaired the malformed v7.550 C-string tail in `ADNewMenus7482.js.inc`; the shipped JS payload reconstructs and parses successfully.
- Preserved App Settings, Interests, About You/memory-grid, keyboard, FULL-route, launch, and transition contracts; no production observer/polling/recurring hierarchy work was added.
- Package/runtime/UI-probe/transition-probe identities are synchronized to v7.553.
- `layout/DEBIAN/postinst`: mode 755.
- `bash scripts/lint-logos.sh`: PASS.
- `sh -n scripts/validate.sh`, `scripts/ui-probe.sh`, `scripts/skeleton-probe.sh`: PASS.
- Critical regressions including `test_v7480_build_syntax_guard.py`, `test_v7533_web_theme_payload_parse.py`, `test_v7548_search_filter_sheet_css.py`, `test_v7550_memory_grid_css.py`, and `test_v7553_filters_exact_owners_no_tweak_size_gate.py`: PASS.
- Exact normalized Python regression inventory used by `scripts/validate.sh`: 208/208 PASS, executed in bounded batches. The monolithic wrapper itself exceeded this session's single-command execution window after beginning the same sequential inventory, so the identical normalized tests were completed in batches instead.

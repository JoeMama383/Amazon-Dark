# v7.547 validation

GitHub Actions exposed a real overlay-merge regression: the existing clone retained `tests/test_v7546_webkit_editing_trait_repair.py`, while the v7.546 source archive overwrote `src/Tweak.xm` without the `ADWebKeyboardStyle7546` production path that test protects.

Final v7.547 tree:
- restores exact `WKContentView` editing-style priming before `%orig` in `becomeFirstResponder`;
- reasserts Dark style across active-responder trait changes and restores the authored override after resign;
- preserves the existing WebKit text-input-traits clamps;
- preserves the v7.546 foreground Hamburger route arbitration;
- includes the retained v7.546 editing-trait regression in the source archive so clean-tree and existing-clone inventories no longer diverge.

Validation completed on the final production source:
- exact normalized `scripts/validate.sh` Python inventory: 204/204 PASS in bounded sequential batches;
- monolithic strict wrapper was attempted and exceeded the sandbox command limit after its initial lint/version gates and early regression tranche, so it is not claimed as completed;
- `scripts/lint-logos.sh`: PASS;
- `sh -n` on validate/UI-probe/skeleton-probe helpers: PASS;
- `test_v7480_build_syntax_guard.py`: PASS;
- `test_v7533_web_theme_payload_parse.py`: PASS;
- normalized retained `test_v7546_webkit_editing_trait_repair.py`: PASS;
- normalized current `test_v7547_webkit_editing_merge_repair.py`: PASS;
- `src/Tweak.xm`: 855923 bytes (<856000 historical gate);
- `src/ADUniversalUIProbe7362.inc`: 94773 bytes (<95000 historical gate);
- `layout/DEBIAN/postinst`: mode 755.

Theos/macOS package compilation is not available in this container; GitHub Actions remains the authoritative compile/link check.

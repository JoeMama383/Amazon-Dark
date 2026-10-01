# v7.546 validation

Evidence basis: source diffing confirms v7.542-v7.545 did not change the dedicated Hamburger FULL sweep logic; only release identities changed in `ADUniversalUIProbe7362.inc`. The reappearing runtime miss is therefore a latent route-arbitration problem, not a regression introduced by the keyboard transition instrumentation itself.

The existing FULL dispatcher checked the visible Person `RCTScrollView#me` before Hamburger. Its visibility predicate checks hidden/alpha/ancestor state and screen intersection, but not occlusion/frontmost ownership. React can retain the previous Person surface underneath an open Hamburger overlay, so FULL can select Person and return before ever evaluating Menu. The Menu detector was also narrower than production theming: it accepted only `RCTScrollView#scrolled-hamburger`, while production menu ownership already recognizes `scrolled-hamburger-view` during hydration.

v7.546 repairs only probe routing. The foreground Hamburger family is identified with bounded hit-test ownership, either known menu identity is accepted, the actual `RCTCustomScrollView` is resolved, Menu is dispatched before retained Person/PDP, and the original offset plus `scrollEnabled`/geometry policy remain unchanged. v7.545 keyboard diagnostics are retained.

Validation on the final source tree:
- normalized `tests/test_*.py`: 202/202 PASS in bounded sequential batches
- `scripts/lint-logos.sh`: PASS
- `sh -n scripts/validate.sh`: PASS
- `sh -n scripts/ui-probe.sh`: PASS
- `sh -n scripts/skeleton-probe.sh`: PASS
- `test_v7480_build_syntax_guard.py`: PASS
- `test_v7533_web_theme_payload_parse.py`: PASS
- `test_v7546_full_menu_route_arbitration.py`: PASS
- current identity synchronization: PASS
- `src/Tweak.xm`: 855792 bytes (<856000 gate)
- `src/ADUniversalUIProbe7362.inc`: 94773 bytes (<95000 historical gate)
- `layout/DEBIAN/postinst`: mode 755

An actual Theos package compile is not available in this container; GitHub Actions remains the authoritative macOS/Theos compile step.

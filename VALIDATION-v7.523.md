# AmazonDark v7.523 validation

Release: `7.523~returns-left-corner-rehydration`

## Probe-backed diagnosis

Reviewed `AmazonDark-v7.522-ui-full-probe-20260930-064214-320-r2.tar` together with the matching post-navigation screenshot. The `yr_item_0` Returns card retains Amazon/React's authored `292 x 69.3` geometry, `1.00` border width and `12.00` border radius. A nested leaf `RCTView` fills the reserved left thumbnail column at card-local approximately `(1,1,60,67.3)` with an opaque black paint plane. Because it is inset one point and spans the card height, it can cover the curved top-left and bottom-left portions of the parent border raster while leaving the straight middle left edge visible.

## v7.523 correction

- Adds an exact narrow-left paint-plane predicate under numeric `yr_item_N` Returns cards.
- Requires an `RCTView` leaf, an exact local left-column geometry window, exact immediate-host fill, and exact Returns-card ancestry.
- Clears only that leaf's background/layer paint; does not alter card frame, bounds, radius, mask, transform, edge widths, or border width.
- Reapplies through existing mount/layout ownership, Returns-section priming, and intercepted React `setBackgroundColor:` writes so submenu-back and other React rehydration cannot repaint the occluding plane opaque.
- Preserves v7.522 glyph-bounds text centering unchanged.

## Targeted regression results

PASS:
- `tests/test_v7523_returns_left_corner_rehydration.py`
- `tests/test_v7522_returns_label_center.py`
- `tests/test_v7521_returns_corners_probe_budget.py`
- `tests/test_v7519_person_deepscan_stock_returns_border.py`
- normalized `tests/test_v7520_full_probe_route_contract_menu_deepscan.py`
- normalized `tests/test_v7507_probe_identity_sync.py`
- normalized `tests/test_probe_handoff.py`
- normalized `tests/test_v7480_build_syntax_guard.py`
- `scripts/lint-logos.sh`
- shell syntax for active probe/validation scripts
- `git diff --no-index --check` for the v7.522 -> v7.523 source delta (no whitespace errors)

The complete strict regression suite was started twice in this container and progressed without a reported test failure through the available execution window, but exceeded the container command timeout before completion. It is therefore not represented as a full-suite PASS.

## Environment limits

No Theos/iOS SDK package build or on-device visual run was possible in this container. GitHub Actions and the device remain the authoritative compile/runtime checks. Device verification should specifically enter a submenu from Person, return to the Person screen, and confirm both left arcs remain visible without affecting the centered `Return request approved` label.

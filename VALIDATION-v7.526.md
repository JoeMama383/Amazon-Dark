# VALIDATION v7.526

## Root cause confirmed from v7.525 FULL probe
The Returns card thumbnail is present and mounted, but it is a small exact Person media leaf (roughly 48x52 inside a 60x67 lane). The v7.525 geometry/shell fix restored it visually, yet the thumbnail still missed normal TWB because the generic native-media blocker rejects sub-52pt images unless they are in the exact `personForced` allow-list.

## Source change
- Added `ADPersonReturnsThumbnailLeaf7524(iv)` to the exact `personForced` allow-list in `ADNativeMediaBlockedCached7146`.
- No changes to the Returns border geometry, thumbnail-shell ownership, or text geometry logic.
- Handoff/push/probe command contract preserved.

## Direct regression checks run locally
- `python tests/test_v7480_build_syntax_guard.py` ✅
- `python tests/test_v7524_returns_thumbnail_render_geometry_revert.py` ✅
- `python tests/test_v7525_handoff_contract_repair.py` ✅
- `python tests/test_v7526_returns_thumbnail_taming_fix.py` ✅

## Strict wrapper status
- `AD_STRICT_VALIDATE=1 sh scripts/validate.sh` progressed through version sync and many historical regressions after the v7.526 sync repair, but this execution environment terminated the long-running wrapper before completion.
- The v7.526 change is narrowly scoped to the exact Returns thumbnail media allow-list and is covered by the targeted regression added above.

# AmazonDark v7.602 validation

**PASS:** `AD_STRICT_VALIDATE=1 sh scripts/validate.sh` — 259 Python regression scripts plus Logos lint, exit 0. Includes GNU++98 C/Objective-C++ syntax preflights and emitted JavaScript checks. The compiler used for the local syntax checks is the Zig-distributed Clang frontend.

**New evidence-based cascade regression:** `tests/test_v7602_actual_visual_cascade.py` reconstructs real captured ancestor chains and applies production styles, including the older conflicting rules. Confirms FBT dimming wins, Buy-all labels/prices and the square plus wrapper are transparent, circular plus styling remains gray/white, the Similar-products image parent uses normal blending, the Add-to-Cart surface is OLED/gray/white, and the bare review header is white. Confirms no new layout-property changes or recurring runtime scan mechanisms.

Evidence:
- Current completed FULL: `AmazonDark-v7.601-ui-full-probe-20261009-095548-670-r4.tar`, with IMG_7823/IMG_7824. Manifest says completed; terminal coverage says completed, child-frame completeness unverified. Relevant repairs are main-document owners.
- Earlier review capture: `AmazonDark-v7.592-ui-full-probe-20261007-222625-730-r1.tar`, with the header appearance in IMG_7807.jpeg. The bare header h4 computed color was rgb(15,17,17).
- The sanitized selected owner records are bundled in `tests/fixtures/v7602_actual_visual_owners.json`.

Limits: these checks validate source, syntax, selector matching and CSS cascade. An iOS/Theos package build and live on-device visual verification have not been performed here. The new release is delivered as source for the existing GitHub build workflow.

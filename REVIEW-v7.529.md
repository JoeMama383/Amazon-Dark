# AmazonDark v7.529 review

Evidence used: v7.526 FULL r1 and v7.528 FULL r1.

Probe-confirmed residuals fixed:
- `._bW9ia_prompt-box_3ENUV` was still `rgba(255,255,255,0.9)` -> OLED black.
- The prompt's trailing overflow control now gets an explicit gray circular ring and an explicit white vertical-ellipsis glyph.
- `._bW9ia_plus-container_1QjeQ` already had the correct 2 px gray ring, but the plus glyph did not accept inherited paint -> explicit white horizontal/vertical bars are rendered on that exact owner.
- `.s-title-instructions-style` remained dark -> exact product title family is white.
- `.s-price-instructions-style` normal `.a-price` remained dark -> normal price text is white while deal/discount/rating accent families are left authored.

Validation performed:
- `test_v7529_interests_header_text_followup.py`: PASS
- `test_v7480_build_syntax_guard.py`: PASS
- logo lint: PASS
- `sh -n scripts/ui-probe.sh`: PASS
- `sh -n scripts/skeleton-probe.sh`: PASS
- normalized `test_v7478_home_pdp_six_fix.py`: PASS
- normalized `test_v7525_handoff_contract_repair.py`: PASS
- normalized `test_v7526_returns_thumbnail_taming_fix.py`: PASS
- normalized `test_v7527_interests_grid_oled_fix.py`: PASS
- normalized `test_v7528_interests_plus_white.py`: PASS
- normalized `test_v7529_interests_header_text_followup.py`: PASS
- strict validator cleared version sync and early historical regressions through the environment timeout; no failure was reported before termination.

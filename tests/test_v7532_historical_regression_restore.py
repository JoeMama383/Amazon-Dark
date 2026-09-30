from pathlib import Path
R=Path(__file__).resolve().parents[1]
C=(R/'layout/DEBIAN/control').read_text(); T=(R/'src/Tweak.xm').read_text(); CSS=(R/'src/ADNewMenus7482.js.inc').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.533~web-theme-parse-regression-repair' in C
assert '#define AD_VERSION "v7.533-web-theme-parse-regression-repair"' in T
assert (R/'tests/test_v7529_interests_header_product_text_fix.py').exists()
for tok in ('#intp-contextual-menu-inline{background:#000!important;background-color:#000!important;border:1px solid #747a7c!important;', '#intp-contextual-menu-inline :is(._bW9ia_more-icon_1Qpwd,img){filter:brightness(0) invert(1)!important;', '._bW9ia_add-icon_21zQ9{filter:brightness(0) invert(1)!important;', '.s-title-instructions-style .a-row.a-color-base', '.s-price-instructions-style :is(.a-price,.a-price-whole,.a-price-symbol,.a-price-fraction,.a-offscreen)'):
    assert tok in CSS, tok
assert 'AmazonDark-v7.533-web-theme-parse-regression-repair-source.zip' in CMD
for good in ('ui-probe.sh export full','ui-probe.sh arm','ui-probe.sh export viewport','skeleton-probe.sh arm transition','skeleton-probe.sh export','git push origin main'):
    assert good in CMD, good
print('PASS: v7.533 restores the omitted v7.529 historical regression and its exact Interests ownership contract')

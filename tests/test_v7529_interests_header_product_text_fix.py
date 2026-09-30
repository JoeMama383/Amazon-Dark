from pathlib import Path
R=Path(__file__).resolve().parents[1]
C=(R/'layout/DEBIAN/control').read_text()
T=(R/'src/Tweak.xm').read_text()
CSS=(R/'src/ADNewMenus7482.js.inc').read_text()
CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.529~interests-header-product-text-fix' in C
assert '#define AD_VERSION "v7.529-interests-header-product-text-fix"' in T
# Exact prompt/action bar owner from current v7.528 FULL.
assert '#interests-ai-sticky-div ._bW9ia_prompt-box_3ENUV{background:#000!important;background-color:#000!important;box-shadow:none!important;}' in CSS
# Exact contextual-menu owner + raster from inherited v7.526 deep FULL.
assert '#intp-contextual-menu-inline{background:#000!important;background-color:#000!important;border:1px solid #747a7c!important;' in CSS
assert '#intp-contextual-menu-inline :is(._bW9ia_more-icon_1Qpwd,img){filter:brightness(0) invert(1)!important;' in CSS
# The plus is a real 33x33 raster; color/fill alone cannot recolor it.
assert '._bW9ia_add-icon_21zQ9{filter:brightness(0) invert(1)!important;' in CSS
# Probe-backed neutral product title/metadata and exact price family are white.
assert '.s-title-instructions-style h2.a-color-base' in CSS
assert '.s-title-instructions-style .a-row.a-color-base' in CSS
assert '.s-title-instructions-style .a-size-mini.a-color-secondary' in CSS
assert '.s-price-instructions-style :is(.a-price,.a-price-whole,.a-price-symbol,.a-price-fraction,.a-offscreen)' in CSS
# Preserve frozen handoff contract.
for good in ('ui-probe.sh export full','ui-probe.sh arm','ui-probe.sh export viewport','skeleton-probe.sh arm transition','skeleton-probe.sh export','git push origin main'):
    assert good in CMD, good
for bad in ('git init','rm -rf .git','git push -uf','ui-probe.sh full','viewport-arm','viewport-export'):
    assert bad not in CMD, bad
print('PASS: v7.529 finishes the exact Interests prompt/menu/plus/product-text/price owners without changing the frozen handoff contract')

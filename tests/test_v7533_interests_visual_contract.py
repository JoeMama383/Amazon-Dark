from pathlib import Path
R=Path(__file__).resolve().parents[1]
CSS=(R/'src/ADNewMenus7482.js.inc').read_text()
CMD=(R/'COMMANDS.md').read_text()
C=(R/'layout/DEBIAN/control').read_text()
assert 'Version: 7.533~web-theme-parse-regression-repair' in C
for token in (
 '#intp-contextual-menu-inline{background:#000!important;background-color:#000!important;border:1px solid #747a7c!important;',
 '#intp-contextual-menu-inline :is(._bW9ia_more-icon_1Qpwd,img){filter:brightness(0) invert(1)!important;',
 '._bW9ia_add-icon_21zQ9{filter:brightness(0) invert(1)!important;',
 '.s-title-instructions-style h2.a-color-base',
 '.s-title-instructions-style .a-row.a-color-base',
 '.s-title-instructions-style .a-size-mini.a-color-secondary',
 '.s-price-instructions-style :is(.a-price,.a-price-whole,.a-price-symbol,.a-price-fraction,.a-offscreen)',
 '.lists-framework-filled-heart-icon',
 ':has(.a-icon-star-mini)',
 'body:has(._bW9ia_prompt-bottom-sheet_1NiWU)',
 'i.a-icon-close._bW9ia_close-icon_3w-DL',
): assert token in CSS, token
for good in ('ui-probe.sh export full','ui-probe.sh arm','ui-probe.sh export viewport','skeleton-probe.sh arm transition','skeleton-probe.sh export','git push origin main'):
    assert good in CMD, good
for bad in ('git init','rm -rf .git','git push -uf','ui-probe.sh full','viewport-arm','viewport-export'):
    assert bad not in CMD, bad
print('PASS: current build preserves exact Interests visual owners, top close-X paint, and frozen handoff contract')

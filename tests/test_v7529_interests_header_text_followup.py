from pathlib import Path
R=Path(__file__).resolve().parents[1]
C=(R/'layout/DEBIAN/control').read_text(); T=(R/'src/Tweak.xm').read_text(); CSS=(R/'src/ADNewMenus7482.js.inc').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.529~interests-header-text-followup' in C
assert '#define AD_VERSION "v7.529-interests-header-text-followup"' in T
for token in (
 '._bW9ia_prompt-box_3ENUV{background:#000!important;background-color:#000!important;',
 '._bW9ia_prompt-box_3ENUV>:last-child:not(:first-child){',
 'border:2px solid #747a7c!important;border-radius:999px!important',
 "content:'\\\\22EE'!important",
 '._bW9ia_plus-container_1QjeQ::before','._bW9ia_plus-container_1QjeQ::after',
 'width:30px!important;height:3px!important','background:#fff!important;background-color:#fff!important',
 '.s-title-instructions-style :is(a,span,div,h2,h3){color:#fff!important;',
 '.s-price-instructions-style .a-price', '.a-size-mini):not(.a-color-price)'):
 assert token in CSS, token
for good in ('ui-probe.sh export full','ui-probe.sh arm','ui-probe.sh export viewport','skeleton-probe.sh arm transition','skeleton-probe.sh export','git push origin main'):
 assert good in CMD, good
for bad in ('git init','rm -rf .git','git push -uf','ui-probe.sh full','viewport-arm','viewport-export'):
 assert bad not in CMD, bad
print('PASS: v7.529 fixes the probe-backed Interests prompt/overflow/plus/title/price residuals and preserves the frozen handoff contract')

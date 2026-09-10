from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.395~ui-coverage-audit-fix' in C
assert '#define AD_VERSION "v7.395-ui-coverage-audit-fix"' in S
block=S.split('// v7.393 FULL r2/r3/r4 (16:59, 17:08, 17:09):',1)[1].split('// v7.390 FULL r2: Subscribe & Save loading transition.',1)[0]

# Returns and Refunds: only DIV card shells get card border ownership; row A.a-box links do not.
assert '.cs-help-landing-section div.a-box' in block
assert '.cs-help-landing-section div.a-box>.a-box-inner' in block
assert '.cs-help-landing-section .a-box-list>li{border-color:#747a7c!important;}' in block
assert '.cs-help-landing-section a.a-touch-link' in block
assert '.cs-help-landing-section i.a-icon-touch-link' in block
assert 'filter:brightness(0) invert(1)!important' in block
# Outside-card stock white separators become OLED rather than another visible line.
assert 'article.help-content p.lead,' in block
assert 'article.help-content .cs-help-landing-section{border-bottom-color:#000!important;}' in block

# Consumer Use Tax: exact table/cell family owns floor, text and border color without geometry changes.
assert 'article.help-content table.a-bordered' in block
assert 'table.a-bordered :is(thead,tbody,tr)' in block
assert 'table.a-bordered :is(th,td)' in block
assert 'background:#000!important' in block
assert 'border-color:#747a7c!important' in block
assert 'color:#e8e6e3!important' in block
# Link and gray families remain dynamic/authored.
assert 'table.a-bordered a *{-webkit-text-fill-color:currentColor!important;}' in block
assert ':not(.lead)' in block and '.a-color-secondary' in block
# Feedback treatment is shared by privacy, returns and tax pages.
for ident in ('#hmd-FeedbackBox','#hmd-ConfirmYesBox','#hmd-ReasonBox','#hmd-ConfirmNoBox','#hmd-CustomerServiceHub'):
    assert ident in block
print('PASS: v7.393 covers Returns cards/rows/chevrons/external rules and Consumer Use Tax table while preserving gray/dynamic help text')

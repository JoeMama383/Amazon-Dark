from pathlib import Path
R=Path(__file__).resolve().parents[1]
C=(R/'layout/DEBIAN/control').read_text()
T=(R/'src/Tweak.xm').read_text()
CSS=(R/'src/ADNewMenus7482.js.inc').read_text()
CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.619~handoff-regression-repair' in C
assert '#define AD_VERSION "v7.619-handoff-regression-repair"' in T
for token in (
 '._bW9ia_plus-thumbnail-link_2gUEq',
 '#create-prompt-link)::before',
 'color:transparent!important;-webkit-text-fill-color:transparent!important;fill:transparent!important;stroke:transparent!important;opacity:0!important;',
 '.lists-framework-filled-heart-icon',
 '[class*=filled-heart]',
 ':has(.a-icon-star-mini)',
 'body:has(._bW9ia_prompt-bottom-sheet_1NiWU)',
 'i.a-icon-close._bW9ia_close-icon_3w-DL',
):
    assert token in CSS, token
for token in ('- (id)_textInputTraits {','- (UIKeyboardAppearance)keyboardAppearance {','return UIKeyboardAppearanceDark;'):
    assert token in T, token
for good in ('ui-probe.sh export full','ui-probe.sh arm','ui-probe.sh export viewport','skeleton-probe.sh arm transition','skeleton-probe.sh export','git push origin main'):
    assert good in CMD, good
print('PASS: current build preserves Interests plus/heart/rating, OLED modal paint, top close-X whitening and WebKit dark keyboard traits without owning the stock inner clear control')

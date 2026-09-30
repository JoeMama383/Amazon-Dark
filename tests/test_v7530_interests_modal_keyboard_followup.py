from pathlib import Path
R=Path(__file__).resolve().parents[1]
C=(R/'layout/DEBIAN/control').read_text()
T=(R/'src/Tweak.xm').read_text()
CSS=(R/'src/ADNewMenus7482.js.inc').read_text()
CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.530~interests-plus-heart-modal-keyboard-fix' in C
assert '#define AD_VERSION "v7.530-interests-plus-heart-modal-keyboard-fix"' in T
for token in (
 '._bW9ia_plus-thumbnail-link_2gUEq',
 '#create-prompt-link)::before',
 'color:transparent!important;-webkit-text-fill-color:transparent!important;fill:transparent!important;stroke:transparent!important;opacity:0!important;',
 '.lists-framework-filled-heart-icon',
 '[class*=filled-heart]',
 ':has(.a-icon-star-mini)',
 'body:has(._bW9ia_prompt-bottom-sheet_1NiWU)',
 '._bW9ia_close-icon_2PTPP',
 'caret-color:#fff!important',
):
    assert token in CSS, token
for token in ('- (id)_textInputTraits {','- (UIKeyboardAppearance)keyboardAppearance {','return UIKeyboardAppearanceDark;'):
    assert token in T, token
for good in ('ui-probe.sh export full','ui-probe.sh arm','ui-probe.sh export viewport','skeleton-probe.sh arm transition','skeleton-probe.sh export','git push origin main'):
    assert good in CMD, good
print('PASS: v7.530 fixes Interests plus/heart/rating and themes the Update your Interest bottom sheet including dark WebKit keyboard traits while preserving the frozen handoff contract')

from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); CSS=(R/'src/ADNewMenus7482.js.inc').read_text(); CMD=(R/'COMMANDS.md').read_text()
for tok in ('WKExtendedTextInputTraits','- (void)setKeyboardAppearance:(UIKeyboardAppearance)a','UIKeyboardAppearanceDark','- (void)restoreDefaultValues','ADDarkWebInputTraits7512(self)'):
    assert tok in S,tok
assert 'class_replaceMethod(c,s,(IMP)ADWebTraitsSetAppearance7536' not in S
assert 'kADWebTraitsAppearance7536' not in S
helper=S[S.index('// v7.537: WebKit has two text-input trait paths.'):S.index('%hook WKContentView')]
assert 'setInterval(' not in helper and 'MutationObserver(' not in helper and 'requestAnimationFrame(' not in helper
modal=CSS[CSS.index('/* v7.537 modal: paint only'): ]
for bad in ('width:','height:','padding:','margin:','position:','border-radius:','border-width:'):
    assert bad not in modal,bad
for good in ('ui-probe.sh export full','ui-probe.sh arm','ui-probe.sh export viewport','skeleton-probe.sh arm transition','skeleton-probe.sh export','git push origin main'):
    assert good in CMD,good
print('PASS: current build preserves v7.536 keyboard-rewrite intent using the exact WebKit extended-traits owner without modal geometry or recurring work')

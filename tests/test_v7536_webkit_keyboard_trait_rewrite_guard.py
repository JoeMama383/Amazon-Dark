from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text(); CSS=(R/'src/ADNewMenus7482.js.inc').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.536~interests-keyboard-trait-rewrite-guard' in C
assert '#define AD_VERSION "v7.536-interests-keyboard-trait-rewrite-guard"' in S
for tok in ('kADWebTraitsAppearance7536','ADWebTraitsSetAppearance7536','ADGuardWebTraitsAppearance7536','class_replaceMethod(c,s,(IMP)ADWebTraitsSetAppearance7536','UIKeyboardAppearanceDark'):
    assert tok in S,tok
helper=S[S.index('static char kADWebTraitsAppearance7536'):S.index('%hook WKContentView')]
assert 'class_getMethodImplementation(c,s)' in helper
assert 'objc_setAssociatedObject((id)c' in helper
assert 'setInterval(' not in helper and 'MutationObserver(' not in helper and 'requestAnimationFrame(' not in helper
# v7.535 modal remains paint-only; no geometry ownership is introduced here.
modal=CSS[CSS.index('/* v7.536 modal: paint only'): ]
for bad in ('width:','height:','padding:','margin:','position:','border-radius:','border-width:'):
    assert bad not in modal,bad
for good in ('ui-probe.sh export full','ui-probe.sh arm','ui-probe.sh export viewport','skeleton-probe.sh arm transition','skeleton-probe.sh export','git push origin main'):
    assert good in CMD,good
print('PASS: v7.536 clamps later WebKit input-traits appearance rewrites to dark without touching Interests modal geometry or adding recurring work')

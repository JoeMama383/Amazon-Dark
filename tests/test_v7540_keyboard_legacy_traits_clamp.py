from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text(); CMD=(R/'COMMANDS.md').read_text(); CSS=(R/'src/ADNewMenus7482.js.inc').read_text()
assert 'Version: 7.540~keyboard-legacy-traits-clamp' in C
assert '#define AD_VERSION "v7.540-keyboard-legacy-traits-clamp"' in S
block=S.split('%hook UITextInputTraits',1)[1].split('%end',1)[0]
assert 'UIKeyboardAppearance a=%orig;' in block
assert 'UIKeyboardAppearance next=gP.enabled?UIKeyboardAppearanceDark:a;' in block
assert 'ADKeyboardTrace7538(self,@"legacy.read",a,next);' in block and 'return next;' in block
assert 'UIKeyboardAppearance next=gP.enabled?UIKeyboardAppearanceDark:a;' in block
assert '%orig(next);' in block and 'ADKeyboardTrace7538(self,@"legacy.write",a,next);' in block
# Keep the extended path as harmless coverage for newer WebKit, but v7.540 must not depend on it.
ext=S[S.index('%hook WKExtendedTextInputTraits'):S.index('%hook WKContentView')]
assert 'UIKeyboardAppearanceDark' in ext
# No new modal geometry or recurring work.
modal=CSS[CSS.index('modal: paint only'):]
for bad in ('width:','height:','padding:','margin:','position:','border-radius:','border-width:'):
    assert bad not in modal,bad
helper=S[S.index('// v7.537: WebKit has two text-input trait paths.'):S.index('%hook WKContentView')]
for bad in ('setInterval(','MutationObserver(','requestAnimationFrame('): assert bad not in helper
for good in ('ui-probe.sh export full','ui-probe.sh arm','ui-probe.sh export viewport','skeleton-probe.sh arm transition','skeleton-probe.sh export','git push origin main'):
    assert good in CMD,good
print('PASS: v7.540 clamps the actual legacy UITextInputTraits handoff to dark on both reads and writes without modal geometry or recurring work')

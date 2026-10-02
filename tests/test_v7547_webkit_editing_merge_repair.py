from pathlib import Path
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text(); U=(R/'src/ADUniversalUIProbe7362.inc').read_text(); C=(R/'layout/DEBIAN/control').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.551~ui-restoration-no-tweak-size-gate' in C
assert '#define AD_VERSION "v7.551-ui-restoration-no-tweak-size-gate"' in T
assert (R/'tests/test_v7546_webkit_editing_trait_repair.py').is_file()
f=T[T.index('%hook WKContentView'):T.index('%end',T.index('%hook WKContentView'))]
assert f.index('ADWebKeyboardStyle7546((UIView *)self,YES);') < f.index('BOOL became=%orig;')
assert 'ADWebKeyboardStyle7546((UIView *)self,NO);' in f
h=T[T.index('static const void *kADWebKeyboardStyle7546'):T.index('%hook WKContentView')]
assert 'UIUserInterfaceStyleDark' in h and 'textInputTraitsForWebView' in h
# Keep the independent v7.546 FULL-menu routing repair while restoring the overwritten keyboard contract.
for token in ('ADUIOwnsHit7520','scrolled-hamburger-view','FULL_ROUTE_ARBITRATION','ADUIScanMenuFull7520'):
    assert token in U,token
for good in ('ui-probe.sh export full','ui-probe.sh arm','ui-probe.sh export viewport','skeleton-probe.sh arm transition','skeleton-probe.sh export','git push origin main'):
    assert good in CMD,good
for bad in ('git init','git push -uf','rm -rf .git'):
    assert bad not in CMD,bad
print('PASS: v7.551 preserves the retained WebKit editing-trait contract without regressing the FULL-menu route repair')

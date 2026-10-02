from pathlib import Path
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.551~ui-restoration-no-tweak-size-gate' in C
f=T[T.index('%hook WKContentView'):T.index('%end',T.index('%hook WKContentView'))]
assert f.index('ADWebKeyboardStyle7546((UIView *)self,YES);')<f.index('BOOL became=%orig;')
assert '- (BOOL)resignFirstResponder {' in f and 'ADWebKeyboardStyle7546((UIView *)self,NO);' in f
assert 'traitCollectionDidChange:(UITraitCollection *)previousTraitCollection' in f
assert 'self.isFirstResponder' in f and 'ADWebKeyboardStyle7546((UIView *)self,YES);' in f
h=T[T.index('static const void *kADWebKeyboardStyle7546'):T.index('%hook WKContentView')]
for token in ('overrideUserInterfaceStyle','UIUserInterfaceStyleDark','textInputTraitsForWebView','objc_getAssociatedObject','objc_setAssociatedObject'):
    assert token in h,token
for bad in ('setFrame:','setBounds:','setCenter:','setTransform:','dispatch_after','NSTimer','CADisplayLink'):
    assert bad not in h,bad
for good in ('ui-probe.sh export full','ui-probe.sh arm','ui-probe.sh export viewport','skeleton-probe.sh arm transition','skeleton-probe.sh export','git push origin main'):
    assert good in CMD,good
print('PASS: v7.551 still primes the WebKit editing trait dark before focus, reasserts it while editing, and restores authored style on resign without geometry or recurring work')

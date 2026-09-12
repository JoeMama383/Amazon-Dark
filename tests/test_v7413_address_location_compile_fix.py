from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text(); C=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.416~location-canonical-owner' in C
hook=S[S.index('%hook RCTScrollContentView'):S.index('%hook RCTScrollView')]
assert 'UIView *v=(UIView *)self;' in hook
assert 'v.layer.backgroundColor=black.CGColor;' in hook
assert 'self.layer.backgroundColor=black.CGColor;' not in hook
# Permission warning cleanup remains.
detect=S[S.index('static int ADPermissionDetectKind7408'):S.index('static int ADPermissionSheetKind7408')]
assert 'micButton' not in detect
# Canonical owner replaces the deleted compile-fixed Aux implementation.
assert 'ADLocationCanonicalScroll7416' in S and 'ADLocationAuxOwnInput7412' not in S
print('PASS: forward-class compile fix is retained while location ownership is simplified')

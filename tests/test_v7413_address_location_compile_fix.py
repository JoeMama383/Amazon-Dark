from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text(); C=(ROOT/'layout/DEBIAN/control').read_text()
UI=(ROOT/'scripts/ui-probe.sh').read_text(); SK=(ROOT/'scripts/skeleton-probe.sh').read_text()
INC=(ROOT/'src/ADUniversalUIProbe7362.inc').read_text(); JS=(ROOT/'src/ADUniversalUIProbe7362.js.inc').read_text()
assert 'Version: 7.413~address-location-compile-fix' in C
assert '#define AD_VERSION "v7.413-address-location-compile-fix"' in S
# The failing Logos hook has self typed as forward-declared RCTScrollContentView.
# Layer access must go through its known UIView base pointer, never self.layer.
hook=S[S.index('%hook RCTScrollContentView'):S.index('%hook RCTScrollView')]
assert 'UIView *v=(UIView *)self;' in hook
assert 'v.layer.backgroundColor=black.CGColor;' in hook
assert 'self.layer.backgroundColor=black.CGColor;' not in hook
# Remove the compiler warning introduced by the permission classifier cleanup.
detect=S[S.index('static int ADPermissionDetectKind7408'):S.index('static int ADPermissionSheetKind7408')]
assert 'micButton' not in detect
assert 'BOOL camera=NO,micTitle=NO;' in detect
# No theming behavior changed: the address/location auxiliary family remains present.
for tok in ('ADAddressManagementJS7412','ADLocationAuxTryMark7412','ADLocationAuxOwnView7412','ADLocationAuxOwnInput7412'):
    assert tok in S,tok
# Probe identities are regenerated for this build.
assert 'VER=7.413' in UI
assert 'AD_PROBE_VERSION=7.413' in SK and 'AD_PROBE_NAME=AmazonDark-v7.413' in SK
assert 'AMAZONDARK v7.413 UNIVERSAL' in INC
assert 'AmazonDark-v7.413-ui-viewport.arm' in INC
assert "version:'7.413'" in JS
print('PASS: v7.413 fixes the RCTScrollContentView forward-class compile error without changing address/location theming')

from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text()
assert 'Version: 7.472~pdp-standalone-unification' in C
assert '#define AD_VERSION "v7.472-pdp-standalone-unification"' in S
assert len(S.encode()) < 856000, len(S.encode())
# Do not regress to the abandoned private _WKUserStyleSheet branch.
for bad in ('_WKUserStyleSheet','_addUserStyleSheet:','ADPDPExactUserCSS7469','ADPDPUserStyleAttach7469','kADPDPUserStyle7469'):
    assert bad not in S,bad
# v7.472 also retires the isolated-world DOM-style experiment: the working standalone engine
# is promoted in the existing page-world frame bridge instead.
for bad in ('ADPDPIsolatedFrameThemeJS7470','ADPDPIsolatedFrameThemeAttach7470','kADPDPIsolatedUS7470'):
    assert bad not in S,bad
f=S[S.index('static void ADForceChildFrameTheme7440'):S.index('@interface ADFrameOwnerBridge7440')]
assert 'ADPDPStandalonePromoteJS7472()' in f and 'ADPageWorld7440()' in f
print('PASS: v7.472 keeps private user-style/isolated experiments retired and promotes PDP ads in the established page-world bridge')

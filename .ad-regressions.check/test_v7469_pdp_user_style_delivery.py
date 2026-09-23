from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text()
assert 'Version: 7.470~pdp-isolated-frame-ownership' in C
assert '#define AD_VERSION "v7.470-pdp-isolated-frame-ownership"' in S
assert len(S.encode()) < 856000, len(S.encode())
# v7.469 repeated the abandoned v7.442/v7.443 private user-style route; do not silently restore it.
for bad in ('_WKUserStyleSheet','_addUserStyleSheet:','ADPDPExactUserCSS7469','ADPDPUserStyleAttach7469','kADPDPUserStyle7469'):
    assert bad not in S,bad
assert 'ADPDPIsolatedFrameThemeAttach7470(ucc);' in S[S.index('static void ADAttachScriptsToUCC710'):S.index('static void ADPaintWrapperChildren7129')]
print('PASS: v7.470 retires the failed v7.469 private user-style route')

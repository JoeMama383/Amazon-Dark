from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text()
assert 'Version: 7.477~pdp-ad-ui-repair' in C
assert '#define AD_VERSION "v7.477-pdp-ad-ui-repair"' in S
assert len(S.encode()) < 856000, len(S.encode())
for bad in ('_WKUserStyleSheet','_addUserStyleSheet:','ADPDPExactUserCSS7469','ADPDPUserStyleAttach7469','kADPDPUserStyle7469','ADPDPIsolatedFrameThemeJS7470','ADPDPIsolatedFrameThemeAttach7470','kADPDPIsolatedUS7470','ADPDPStandalonePromoteJS7472'):
    assert bad not in S,bad
g=S[S.index('static NSString *ADPDPGridCarouselFix7454'):S.index('static NSString *ADPDPCompletionJS7405')]
assert 'new CSSStyleSheet()' in g and 'document.adoptedStyleSheets=a.concat([sh])' in g and "data-ad7473-survivor" in g
core=S[S.index('static NSString *ADCoreWebJS7271'):S.index('// v7.388: WKUserScript')]
assert 'ADPDPGridCarouselFix7454()' in core
print('PASS: v7.473 keeps private user-style/isolated experiments retired and uses the normal all-frame core script with a constructable survivor sheet')

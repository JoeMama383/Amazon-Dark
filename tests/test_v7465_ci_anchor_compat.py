from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.473~standalone-survivor-sheet' in C
assert '#define AD_VERSION "v7.473-standalone-survivor-sheet"' in S
assert len(S.encode()) < 856000, len(S.encode())
marker='// One immutable document-start program per strength replaces four separately\n// allocated/compiled WKUserScripts while preserving their proven execution order.'
a=S.index('static NSString *ADAddressManagementJS7412(void){'); m=S.index(marker,a); g=S.index('static long gADCoreWebJSStrength7271=-1;',a)
assert a < m < g
web=S[a:m]; assert '#ya-myab-address-add-link' in web and '[id^=ya-myab-display-address-block-]' in web
for bad in ('new MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"): assert bad not in web,bad
for bad in ['kADPDPIsolatedUS7470','ADPDPIsolatedFrameThemeJS7470','ADPDPIsolatedFrameThemeAttach7470','_WKUserStyleSheet','ADPDPStandalonePromoteJS7472']:
    assert bad not in S,bad
grid=S[S.index('static NSString *ADPDPGridCarouselFix7454'):S.index('static NSString *ADPDPCompletionJS7405')]
for tok in ['document.adoptedStyleSheets','__ad7454PDPAdSurvivor','data-ad7473-survivor']:
    assert tok in grid,tok
for h in ['## FULL — v7.473','## VIEWPORT — v7.473','## TRANSITION — v7.473']: assert h in CMD
print('PASS: v7.473 preserves legacy anchors and retires the failed promotion lane in favor of the core survivor sheet')

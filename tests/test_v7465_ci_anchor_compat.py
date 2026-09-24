from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.472~pdp-standalone-unification' in C
assert '#define AD_VERSION "v7.472-pdp-standalone-unification"' in S
assert len(S.encode()) < 856000, len(S.encode())
marker='// One immutable document-start program per strength replaces four separately\n// allocated/compiled WKUserScripts while preserving their proven execution order.'
a=S.index('static NSString *ADAddressManagementJS7412(void){'); m=S.index(marker,a); g=S.index('static long gADCoreWebJSStrength7271=-1;',a)
assert a < m < g
web=S[a:m]
assert '#ya-myab-address-add-link' in web and '[id^=ya-myab-display-address-block-]' in web
for bad in ('new MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in web,bad
# Failed isolated/user-style lanes stay retired; page-world bridge + mature standalone promotion is current.
for bad in ['kADPDPIsolatedUS7470','ADPDPIsolatedFrameThemeJS7470','ADPDPIsolatedFrameThemeAttach7470','_WKUserStyleSheet']:
    assert bad not in S,bad
for tok in ['ADPDPStandalonePromoteJS7472','ADPageWorld7440()','data-ad7472-pdp-standalone','data-ad7472-pdp-unified']:
    assert tok in S,tok
for h in ['## FULL — v7.472','## VIEWPORT — v7.472','## TRANSITION — v7.472']: assert h in CMD
print('PASS: v7.472 preserves legacy source anchors while using page-world standalone promotion')

from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.470~pdp-isolated-frame-ownership' in C
assert '#define AD_VERSION "v7.470-pdp-isolated-frame-ownership"' in S
assert len(S.encode()) < 856000, len(S.encode())
marker='// One immutable document-start program per strength replaces four separately\n// allocated/compiled WKUserScripts while preserving their proven execution order.'
a=S.index('static NSString *ADAddressManagementJS7412(void){'); m=S.index(marker,a); g=S.index('static long gADCoreWebJSStrength7271=-1;',a)
assert a < m < g
web=S[a:m]
assert '#ya-myab-address-add-link' in web and '[id^=ya-myab-display-address-block-]' in web
for bad in ('new MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in web,bad
for tok in ['kADPDPIsolatedUS7470','ADPDPIsolatedFrameThemeJS7470','ADPDPIsolatedFrameThemeAttach7470','ADUIProbeWorld7453()','data-ad7470-pdp-theme']:
    assert tok in S,tok
assert '_WKUserStyleSheet' not in S
for h in ['## FULL — v7.470','## VIEWPORT — v7.470','## TRANSITION — v7.470']:
    assert h in CMD
print('PASS: v7.470 preserves legacy source anchors and uses the probe-proven isolated content world')

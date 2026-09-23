from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/ADUniversalUIProbe7362.inc').read_text()
T=(R/'src/Tweak.xm').read_text()
C=(R/'layout/DEBIAN/control').read_text()
UI=(R/'scripts/ui-probe.sh').read_text()
SK=(R/'scripts/skeleton-probe.sh').read_text()

assert 'Version: 7.459~viewport-terminal-home-hero-pill' in C
assert '#define AD_VERSION "v7.459-viewport-terminal-home-hero-pill"' in T
assert 'VER=7.459' in UI
assert 'AD_PROBE_VERSION=7.459' in SK and 'AD_PROBE_NAME=AmazonDark-v7.459' in SK

# Product classification remains native-route first, #dp fallback second.
classifier=S[S.index('static BOOL ADUIURLIsPDP7451'):S.index('static NSString *ADPDPStreamJS7451')]
for route in ['@"/dp/"','@"/gp/product/"','@"/gp/aw/d/"']:
    assert route in classifier, route
assert "document.getElementById('dp')" in classifier

# v7.459 corrects the mistaken no-scroll diagnosis: verify modal unlock first.
router=S[S.index('static void ADUIProcessWebViews7364'):S.index('static void ADUIScanNativeAxis7364')]
assert 'ADUIEnsurePDPScrollable7456' in router
assert router.index('ADUIEnsurePDPScrollable7456') < router.index('ADUIScanWebViewFull7364')
assert 'ADUIScanPDPManual7455' not in S

# A PDP FULL session also skips generic native scroll driving.
capture=S[S.index('static void ADCaptureUniversalUIProbe7362(BOOL viewportOnly,NSString *trigger){'):S.index('static NSString *ADUIViewportArmPath7362')]
assert 'ADUIDetectPDPSession7451(webs' in capture
assert 'FULL_ROUTE_POLICY pdpDetected=' in capture
assert 'PDP_READONLY_NATIVE_SCROLL policy=skipped' in capture
assert capture.index('if(gADUIFullHasPDP7451)') < capture.index('ADUINativeScrollCandidatesAsync7449(path,cap')

print('PASS: v7.459 routes Product Detail through manual read-only checkpoints and preserves automatic FULL elsewhere')

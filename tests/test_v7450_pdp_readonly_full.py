from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/ADUniversalUIProbe7362.inc').read_text()
T=(R/'src/Tweak.xm').read_text()
C=(R/'layout/DEBIAN/control').read_text()
UI=(R/'scripts/ui-probe.sh').read_text()
SK=(R/'scripts/skeleton-probe.sh').read_text()

assert 'Version: 7.455~pdp-manual-full' in C
assert '#define AD_VERSION "v7.455-pdp-manual-full"' in T
assert 'VER=7.455' in UI
assert 'AD_PROBE_VERSION=7.455' in SK and 'AD_PROBE_NAME=AmazonDark-v7.455' in SK

# Product classification remains native-route first, #dp fallback second.
classifier=S[S.index('static BOOL ADUIURLIsPDP7451'):S.index('static NSString *ADPDPStreamJS7451')]
for route in ['@"/dp/"','@"/gp/product/"','@"/gp/aw/d/"']:
    assert route in classifier, route
assert "document.getElementById('dp')" in classifier

# v7.455 restores the proven product-specific no-scroll boundary. PDP routes go
# to the manual checkpoint scanner; ordinary menus keep the automatic walker.
router=S[S.index('static void ADUIProcessWebViews7364'):S.index('static void ADUIScanNativeAxis7364')]
assert 'if(gADUIFullHasPDP7451)' in router
assert 'ADUIScanPDPManual7455(wv,index,path,cap,nextWeb)' in router
assert 'ADUIScanWebViewFull7364(wv,index,path,cap,nextWeb)' in router
assert router.index('if(gADUIFullHasPDP7451)') < router.index('ADUIScanWebViewFull7364(wv,index,path,cap,nextWeb)')

manual=S[S.index('static NSString *ADPDPManualTrackerJS7455'):S.index('static void ADUIScanNativeAxis7364')]
for tok in ['PDP_MANUAL_FULL','PDP_MANUAL_TRACKER_ACK','ADPDPManualSampleJS7455','PDP_MANUAL_VIEWPORT_',
            'programmaticScrollWrites=0','manual-checkpoint-no-scroll-mutation']:
    assert tok in manual or tok in S, tok
# The PDP path must never call the scroll mutator or UIKit offset writer.
for bad in ['ADUIScrollCommand7446(wv', 'setContentOffset:']:
    assert bad not in manual, bad

# A PDP FULL session also skips generic native scroll driving.
capture=S[S.index('static void ADCaptureUniversalUIProbe7362(BOOL viewportOnly,NSString *trigger){'):S.index('static NSString *ADUIViewportArmPath7362')]
assert 'ADUIDetectPDPSession7451(webs' in capture
assert 'FULL_ROUTE_POLICY pdpDetected=' in capture
assert 'PDP_READONLY_NATIVE_SCROLL policy=skipped' in capture
assert capture.index('if(gADUIFullHasPDP7451)') < capture.index('ADUINativeScrollCandidatesAsync7449(path,cap')

print('PASS: v7.455 routes Product Detail through manual read-only checkpoints and preserves automatic FULL elsewhere')

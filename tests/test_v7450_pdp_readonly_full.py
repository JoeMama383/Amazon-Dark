from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/ADUniversalUIProbe7362.inc').read_text()
T=(R/'src/Tweak.xm').read_text()
C=(R/'layout/DEBIAN/control').read_text()
UI=(R/'scripts/ui-probe.sh').read_text()
SK=(R/'scripts/skeleton-probe.sh').read_text()

assert 'Version: 7.454~carousel-probe-order' in C
assert '#define AD_VERSION "v7.454-carousel-probe-order"' in T
assert 'VER=7.454' in UI
assert 'AD_PROBE_VERSION=7.454' in SK and 'AD_PROBE_NAME=AmazonDark-v7.454' in SK

# Exact PDP classification is native-route first, #dp fallback second.
classifier=S[S.index('static BOOL ADUIURLIsPDP7451'):S.index('static NSString *ADPDPStreamJS7451')]
for route in ['@"/dp/"','@"/gp/product/"','@"/gp/aw/d/"']:
    assert route in classifier, route
assert "document.getElementById('dp')" in classifier

# The PDP Web collector remains read-only, but delivery is now one start call plus an
# asynchronous message stream. It may read WKScrollView geometry, but cannot mutate it.
pdp=S[S.index('static NSString *ADPDPStreamJS7451'):S.index('static void ADUIProcessWebViews7364')]
for tok in ['PDP_STREAM_FULL','ADPDPStreamJS7451','WKScriptMessageHandler','PDP_STREAM_START_ACK','PDP_STREAM_TIMEOUT']:
    assert tok in pdp, tok
for bad in ['setContentOffset','scrollEnabled=', 'ADUIScrollCommand7446', 'scrollTo(', '__adUIWalkCommand', 'ADUIWebJS7364(@"full"']:
    assert bad not in pdp, bad

# v7.454: all WebViews start the guarded universal walk first; detailed streaming
# inventory follows the root pass and still gates owner/catch-up completion on failures.
router=S[S.index('static void ADUIProcessWebViews7364'):S.index('static void ADUIScanNativeAxis7364')]
assert 'ADUIScanPDPStreaming7451' not in router
assert 'ADUIScanWebViewFull7364(wv,index,path,cap,nextWeb)' in router
assert 'gADUIFullHasPDP7451' not in router
full=S[S.index('static void ADUIScanWebViewFull7364'):S.index('static BOOL ADUIURLIsPDP7451')]
assert 'ADUIScanPDPStreaming7451(wv,index,path,cap,^' in full
assert 'if([gADUIFailedWebs7446 containsObject:wv])' in full
assert 'static void ADUIDetectPDPSession7451' in S

# A PDP FULL session must also skip generic native scroll driving.
capture=S[S.index('static void ADCaptureUniversalUIProbe7362(BOOL viewportOnly,NSString *trigger){'):S.index('static NSString *ADUIViewportArmPath7362')]
assert 'ADUIDetectPDPSession7451(webs' in capture
assert 'FULL_ROUTE_POLICY pdpDetected=' in capture
assert 'PDP_READONLY_NATIVE_SCROLL policy=skipped' in capture
assert 'if(gADUIFullHasPDP7451)' in capture
assert capture.index('if(gADUIFullHasPDP7451)') < capture.index('ADUINativeScrollCandidatesAsync7449(path,cap')

# Existing generic machinery remains available for other menus; no production recurring Web machinery is introduced.
for tok in ['static void ADUIScanWebViewFull7364','static void ADUINativeScrollCandidatesAsync7449','static void ADUIFinishCapture7364']:
    assert tok in S, tok
new=S[S.index('static BOOL ADUIURLIsPDP7451') : S.index('static void ADUIScanNativeAxis7364')]
for bad in ['new MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"]:
    assert bad not in new, bad

print('PASS: v7.454 keeps inventory read-only and routes PDP through the guarded universal walk')

from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/ADUniversalUIProbe7362.inc').read_text()
T=(R/'src/Tweak.xm').read_text()
C=(R/'layout/DEBIAN/control').read_text()
UI=(R/'scripts/ui-probe.sh').read_text()
SK=(R/'scripts/skeleton-probe.sh').read_text()

assert 'Version: 7.450~pdp-readonly-full' in C
assert '#define AD_VERSION "v7.450-pdp-readonly-full"' in T
assert 'VER=7.450' in UI
assert 'AD_PROBE_VERSION=7.450' in SK and 'AD_PROBE_NAME=AmazonDark-v7.450' in SK

# Exact PDP classification is native-route first, #dp fallback second.
classifier=S[S.index('static BOOL ADUIURLIsPDP7450'):S.index('static void ADUIScanPDPReadOnly7450')]
for route in ['@"/dp/"','@"/gp/product/"','@"/gp/aw/d/"']:
    assert route in classifier, route
assert "document.getElementById('dp')" in classifier

# The PDP Web collector is read-only. It may read WKScrollView geometry, but cannot mutate it.
pdp=S[S.index('static void ADUIScanPDPReadOnly7450'):S.index('static void ADUIProcessWebViews7364')]
for tok in ['PDP_READONLY_FULL_DOM','PDP_READONLY_CATCHUP_DOM','mutated=0','ADUIWebJS7364(@"full",@"final-full",0)','ADUIWebJS7364(@"full",@"catchup-full",1)']:
    assert tok in pdp, tok
for bad in ['setContentOffset','scrollEnabled=', 'ADUIScrollCommand7446', 'scrollTo(', '__adUIWalkCommand']:
    assert bad not in pdp, bad

# Routing is narrow: PDP takes read-only path; every other FULL WebView keeps v7.449 generic path.
router=S[S.index('static void ADUIProcessWebViews7364'):S.index('static void ADUIScanNativeAxis7364')]
assert 'if(gADUIFullHasPDP7450)' in router
assert 'ADUIScanPDPReadOnly7450' in router
assert 'ADUIScanWebViewFull7364' in router
assert 'static void ADUIDetectPDPSession7450' in S

# A PDP FULL session must also skip generic native scroll driving.
capture=S[S.index('static void ADCaptureUniversalUIProbe7362(BOOL viewportOnly,NSString *trigger){'):S.index('static NSString *ADUIViewportArmPath7362')]
assert 'ADUIDetectPDPSession7450(webs' in capture
assert 'FULL_ROUTE_POLICY pdpReadOnly=' in capture
assert 'PDP_READONLY_NATIVE_SCROLL policy=skipped' in capture
assert 'if(gADUIFullHasPDP7450)' in capture
assert capture.index('if(gADUIFullHasPDP7450)') < capture.index('ADUINativeScrollCandidatesAsync7449(path,cap')

# Existing generic machinery remains available for other menus; no production recurring Web machinery is introduced.
for tok in ['static void ADUIScanWebViewFull7364','static void ADUINativeScrollCandidatesAsync7449','static void ADUIFinishCapture7364']:
    assert tok in S, tok
new=S[S.index('// v7.450: PDP is a special renderer.') : S.index('static void ADUIScanNativeAxis7364')]
for bad in ['new MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"]:
    assert bad not in new, bad

print('PASS: v7.450 makes only PDP FULL read-only and preserves non-PDP FULL plus VIEWPORT/TRANSITION architecture')

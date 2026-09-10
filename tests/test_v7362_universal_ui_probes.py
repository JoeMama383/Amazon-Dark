from pathlib import Path
import json, hashlib, subprocess, tempfile

ROOT=Path(__file__).resolve().parents[1]
t=(ROOT/'src/Tweak.xm').read_text()
inc=(ROOT/'src/ADUniversalUIProbe7362.inc').read_text()
jsinc=(ROOT/'src/ADUniversalUIProbe7362.js.inc').read_text()
ctl=(ROOT/'layout/DEBIAN/control').read_text()
helper=(ROOT/'scripts/ui-probe.sh').read_text()

assert 'Version: 7.387~runtime-css-optimization' in ctl
assert '#define AD_VERSION "v7.387-runtime-css-optimization"' in t
assert '#include "ADUniversalUIProbe7362.inc"' in t

# Architectural convergence: the old per-menu capture engines and historical v7.309 output stems are removed.
for token in [
    'ADCapturePersonProbe7233','ADCaptureCartProbe7241','ADCaptureMenuProbe7252',
    'ADCaptureAlexaProbe7269','ADCapturePersonSubmenuProbe7298','ADCaptureHomeFrameProbe7265',
    'ADCaptureProductScrollProbe7272','person-ui-probe','cart-ui-probe','menu-ui-probe',
    'alexa-ui-probe','person-submenu-hybrid-probe','home-frame-probe','product-scroll-probe',
    'AmazonDark-v7.309-'
]:
    assert token not in t, token

# Exactly two UI categories, one trigger each.
assert 'ui-full-probe' in inc and 'ui-viewport-probe' in inc
assert inc.count('UIApplicationUserDidTakeScreenshotNotification') == 1
assert inc.count('dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL,SIGUSR2') == 1
assert 'ADCaptureUniversalUIProbe7362(NO,trigger)' in inc
assert 'ADUIConsumeViewportArm7362()' in inc and 'ADCaptureUniversalUIProbe7362(YES,@"armed-SIGUSR2")' in inc
assert 'AmazonDark-v7.387-ui-viewport.arm' in inc
assert 'ADSkelTrigger7339(trigger)' in inc  # skeleton/transition SIGUSR2 behavior still wins when armed

# Universal scope: every current on-screen WKWebView plus native hierarchy, no tab routing.
assert 'ADUIWebViews7362' in inc and 'ADTrackedWebViews()' in inc
assert 'UIApplication.sharedApplication.windows' in inc
for token in ['meTab','cartTab','menuTab','rufusTab','ADProbeTabSelected7254','ADProductScrollWebView7272']:
    assert token not in inc, token

# Viewport mode stays current-frame only. FULL restores the old finite sweep behavior universally.
js=''.join(json.loads(line) for line in jsinc.splitlines())
assert "viewportOnly=mode==='viewport'" in js
assert 'walkRoot(document.documentElement' in js
assert 'if(!viewportOnly||(visible&&intersects(r)))' in js
assert 'elementsFromPoint' in js
assert 'shadowRoot' in js and 'contentDocument' in js
assert 'textContent' in js and 'ownHash' in js and 'allHash' in js
for bad in ['setInterval(', 'requestAnimationFrame(', 'MutationObserver(', "addEventListener('scroll'", 'scrollTo(', 'scrollBy(']:
    assert bad not in js, bad


# FULL screenshot mode must perform finite renderer sweeps, not merely inspect the currently mounted tree.
for token in [
    'ADUIScanWebViewFull7364','INITIAL_FULL_DOM','SWEEP_STEP_','POST_SWEEP_FULL_DOM',
    'setContentOffset:','originalScroll','ADUINativeScrollCandidates7364',
    'NATIVE_SCROLL_SELECTION','ADUIScanNativeAxis7364','NATIVE_SWEEP_END',
    'NATIVE FINAL FULL SNAPSHOT','ADUIAppendTerminal7364','cap-8192ULL'
]:
    assert token in inc, token
assert 'ADUIProcessWebViews7364(webs,0,viewportOnly' in inc
assert 'if(viewportOnly){ADUIFinishCapture7364(YES' in inc
assert 'ADUINativeScrollCandidates7364(path,cap)' in inc
assert 'sv.scrollEnabled=originalScroll' in inc
assert 'WEB_SWEEP_END' in inc and 'restoredOffset=' in inc
assert 'all scrolling/traversal is finite and exists only after an explicit trigger' in inc

# The C string include emits exactly the intended JavaScript in the C++98 dialect used by the tweak.
with tempfile.TemporaryDirectory(prefix='ad-ui-inc-') as td:
    td=Path(td)
    bridge=td/'bridge.cpp'
    bridge.write_text('#include <cstdio>\nstatic const char s[]=\n#include "ADUniversalUIProbe7362.js.inc"\n;\nint main(){return std::fwrite(s,1,sizeof(s)-1,stdout)==sizeof(s)-1?0:1;}\n')
    out=td/'probe'
    subprocess.run(['c++','-std=gnu++98','-Wall','-Wextra','-Werror','-I',str(ROOT/'src'),str(bridge),'-o',str(out)],check=True)
    emitted=subprocess.check_output([str(out)]).decode()
    assert emitted==js
    subprocess.run(['node','--check'],input=emitted,text=True,check=True)

# Arming helper is one-shot viewport only; screenshot full capture intentionally needs no helper mode.
assert 'Usage: sh scripts/ui-probe.sh arm | export | status | disarm' in helper
assert "printf 'viewport %s\\n'" in helper
assert 'kill -USR2 "$pid"' in helper
assert 'ui-full-probe' in helper and 'ui-viewport-probe' in helper
assert "grep -q '================ END RUN ================'" in helper
assert 'still sweeping' in helper
assert 'screenshot' not in helper.lower() or 'FULL capture is intentionally screenshot-only' in helper
subprocess.run(['sh','-n',str(ROOT/'scripts/ui-probe.sh')],check=True)

print('PASS: v7.370 has exactly two universal UI probe categories and no route-specific dispatcher')
print('PASS: screenshot -> finite universal Web/native full sweep with restoration; armed SIGUSR2 -> current viewport only')
print('PASS: universal JS string compiles in gnu++98, parses in Node, and has no recurring/live scan machinery')

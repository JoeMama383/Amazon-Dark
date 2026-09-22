from pathlib import Path
import json, hashlib, subprocess, tempfile

ROOT=Path(__file__).resolve().parents[1]
t=(ROOT/'src/Tweak.xm').read_text()
inc=(ROOT/'src/ADUniversalUIProbe7362.inc').read_text()
jsinc=(ROOT/'src/ADUniversalUIProbe7362.js.inc').read_text()
frameinc=(ROOT/'src/ADUniversalUIProbe7362.frame.js.inc').read_text()
ctl=(ROOT/'layout/DEBIAN/control').read_text()
helper=(ROOT/'scripts/ui-probe.sh').read_text()

assert 'Version: 7.453~isolated-probe' in ctl
assert '#define AD_VERSION "v7.453-isolated-probe"' in t
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

# Exactly two UI categories: screenshot FULL and one-shot next-background VIEWPORT.
assert 'ui-full-probe' in inc and 'ui-viewport-probe' in inc
assert inc.count('UIApplicationUserDidTakeScreenshotNotification') == 1
assert inc.count('dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL,SIGUSR2') == 1
assert 'ADCaptureUniversalUIProbe7362(NO,trigger)' in inc
assert 'ADUIConsumeViewportArm7362()' in inc and 'ADCaptureUniversalUIProbe7362(YES,@"armed-will-resign-active")' in inc
assert inc.count('UIApplicationWillResignActiveNotification') == 1
assert 'ADUIBeginViewportBackgroundTask7447' in inc and 'ADUIEndViewportBackgroundTask7447' in inc
assert 'ADUIWaitForeground7446' not in inc
assert 'applicationState==UIApplicationStateActive&&ADUIConsumeViewportArm7362()' in inc
assert 'AmazonDark-v7.453-ui-viewport.arm' in inc
assert 'ADSkelTrigger7339(trigger); ADCaptureUniversalUIProbe7362(NO,trigger)' in inc  # transition marking no longer suppresses FULL

# Universal scope: every current on-screen WKWebView plus native hierarchy, no tab routing.
assert 'ADUIWebViews7362' in inc and 'ADTrackedWebViews()' in inc
assert 'UIApplication.sharedApplication.windows' in inc
for token in ['meTab','cartTab','menuTab','rufusTab','ADProbeTabSelected7254','ADProductScrollWebView7272']:
    assert token not in inc, token

# Viewport mode stays current-frame only. FULL restores the old finite sweep behavior universally.
js=''.join(json.loads(line) for line in jsinc.splitlines())
assert "viewportOnly=mode==='viewport'" in js
assert 'document.createTreeWalker(document.documentElement' in js
assert 'if(!viewportOnly||(visible&&intersects(r)))' in js
assert 'elementsFromPoint' in js
assert 'shadowRoot' in js and 'contentDocument' not in js
assert 'broadcastFrames' in js and '__adUIProbe7433' in js and 'window.__adUIProbeNonce7433' in js
assert 'textContent' in js and 'ownHash' in js and 'boundedOwnText' in js
assert 'paintRisk' in js and 'dark-on-dark' in js and 'effectiveBg' in js
for bad in ['setInterval(', 'requestAnimationFrame(', 'MutationObserver(', "addEventListener('scroll'", 'scrollTo(', 'scrollBy(']:
    assert bad not in js, bad


# FULL screenshot mode must perform finite renderer sweeps, not merely inspect the currently mounted tree.
for token in [
    'ADUIScanWebViewFull7364','PDP_STREAM_COMPLETE','ADUIScanPDPStreaming7451','SWEEP_SAMPLE_','WEB_DOCUMENT_SWEEP',
    'setContentOffset:','scrollLock=none','ADUINativeScrollCandidatesAsync7449',
    'NATIVE_SCROLL_SELECTION','ADUIScanNativeAxis7364','NATIVE_SWEEP_END',
    'NATIVE_FINAL policy=initial-hierarchy-retained','ADUIAppendTerminal7364','cap-8192ULL'
]:
    assert token in inc, token
assert 'ADUIProcessWebViews7364(webs,0,NO' in inc and 'ADUIProcessWebViews7364(webs,0,YES' in inc
assert 'ADUIFinishCapture7364(YES' in inc
assert 'ADUINativeScrollCandidatesAsync7449(path,cap' in inc
assert 'scrollEnabled=NO' not in inc
assert 'WEB_SWEEP_END' in inc and 'restoredOffset=' in inc
assert 'FULL traversal is cooperative and opt-in' in inc

# Cross-origin frame coverage is provided by a dormant all-frame documentStart bridge.
framejs=''.join(json.loads(line) for line in frameinc.splitlines())
for token in ['adUniversalUI7433','window.addEventListener(\'message\'','forMainFrameOnly:NO','CROSS_FRAME_DOM','frame origin/path/referrer are hash-only']:
    if token=='forMainFrameOnly:NO': assert token in inc
    elif token=='CROSS_FRAME_DOM': assert token in inc
    elif token=='frame origin/path/referrer are hash-only': assert token in inc
    else: assert token in framejs, token
assert 'contentDocument' not in framejs
assert 'textContent' in framejs and 'ownHash' in framejs and 'boundedOwnText' in framejs
assert 'paintRisk' in framejs and 'dark-on-dark' in framejs and 'light-on-light' in framejs
assert 'originHash' in framejs and 'pathHash' in framejs and 'referrerHash' in framejs
assert 'payload.slice' in framejs and 'chunkSize=96000' in framejs
assert 'document.querySelectorAll(\'iframe\')' in framejs
for bad in ['setInterval(', 'requestAnimationFrame(', 'MutationObserver(', "addEventListener('scroll'"]:
    assert bad not in framejs, bad

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
    fbridge=td/'frame.cpp'
    fbridge.write_text('#include <cstdio>\nstatic const char s[]=\n#include "ADUniversalUIProbe7362.frame.js.inc"\n;\nint main(){return std::fwrite(s,1,sizeof(s)-1,stdout)==sizeof(s)-1?0:1;}\n')
    fout=td/'frame-probe'
    subprocess.run(['c++','-std=gnu++98','-Wall','-Wextra','-Werror','-I',str(ROOT/'src'),str(fbridge),'-o',str(fout)],check=True)
    femitted=subprocess.check_output([str(fout)]).decode()
    assert femitted==framejs
    subprocess.run(['node','--check'],input=femitted,text=True,check=True)

# Arming helper is one-shot viewport only; screenshot FULL needs no shell arm.
assert 'Usage: sh scripts/ui-probe.sh arm | export full | export viewport | status | disarm' in helper
assert "printf 'viewport %s\\n'" in helper
assert 'kill -USR2' not in helper and 'find_pid' not in helper
assert 'next background transition' in helper
assert '.tar' in helper and '.zip' not in helper
assert 'ui-$mode.state' in helper and 'ui-$mode-probe-' in helper
assert "grep -q '================ END RUN ================'" in helper
assert 'still running or incomplete' in helper
assert 'FULL: screenshot-triggered' in helper
subprocess.run(['sh','-n',str(ROOT/'scripts/ui-probe.sh')],check=True)

print('PASS: v7.453 retains exactly two universal UI probe categories and no route-specific dispatcher')
print('PASS: screenshot -> finite native/main-Web/child-SafeFrame FULL; armed next-background lifecycle -> last-foreground VIEWPORT')
print('PASS: main + cross-frame probe programs compile in gnu++98, parse in Node, and have no recurring scan machinery')

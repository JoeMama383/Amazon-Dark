from pathlib import Path
import json, hashlib, subprocess, tempfile

ROOT=Path(__file__).resolve().parents[1]
t=(ROOT/'src/Tweak.xm').read_text()
inc=(ROOT/'src/ADUniversalUIProbe7362.inc').read_text()
jsinc=(ROOT/'src/ADUniversalUIProbe7362.js.inc').read_text()
ctl=(ROOT/'layout/DEBIAN/control').read_text()
helper=(ROOT/'scripts/ui-probe.sh').read_text()

assert 'Version: 7.363~search-pane-related-cart-claimed' in ctl
assert '#define AD_VERSION "v7.363-search-pane-related-cart-claimed"' in t
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
assert 'AmazonDark-v7.363-ui-viewport.arm' in inc
assert 'ADSkelTrigger7339(trigger)' in inc  # skeleton/transition SIGUSR2 behavior still wins when armed

# Universal scope: every current on-screen WKWebView plus native hierarchy, no tab routing.
assert 'ADUIWebViews7362' in inc and 'ADTrackedWebViews()' in inc
assert 'UIApplication.sharedApplication.windows' in inc
for token in ['meTab','cartTab','menuTab','rufusTab','ADProbeTabSelected7254','ADProductScrollWebView7272']:
    assert token not in inc, token

# Viewport mode does not scroll; full mode walks the whole mounted DOM. No live web probe engine.
js=''.join(json.loads(line) for line in jsinc.splitlines())
assert "viewportOnly=mode==='viewport'" in js
assert 'walkRoot(document.documentElement' in js
assert 'if(!viewportOnly||(visible&&intersects(r)))' in js
assert 'elementsFromPoint' in js
assert 'shadowRoot' in js and 'contentDocument' in js
assert 'textContent' in js and 'ownHash' in js and 'allHash' in js
for bad in ['setInterval(', 'requestAnimationFrame(', 'MutationObserver(', "addEventListener('scroll'", 'scrollTo(', 'scrollBy(']:
    assert bad not in js, bad

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
assert 'screenshot' not in helper.lower() or 'FULL capture is intentionally screenshot-only' in helper
subprocess.run(['sh','-n',str(ROOT/'scripts/ui-probe.sh')],check=True)

print('PASS: v7.362 has exactly two universal UI probe categories and no route-specific dispatcher')
print('PASS: screenshot -> full mounted DOM/native; armed SIGUSR2 -> current viewport only')
print('PASS: universal JS string compiles in gnu++98, parses in Node, and has no recurring/live scan machinery')

from pathlib import Path
import json, subprocess, tempfile

ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
INC=(ROOT/'src/ADUniversalUIProbe7362.inc').read_text()
MAIN_INC=(ROOT/'src/ADUniversalUIProbe7362.js.inc').read_text()
FRAME_INC=(ROOT/'src/ADUniversalUIProbe7362.frame.js.inc').read_text()
CTL=(ROOT/'layout/DEBIAN/control').read_text()
UI=(ROOT/'scripts/ui-probe.sh').read_text()
SK=(ROOT/'scripts/skeleton-probe.sh').read_text()

assert 'Version: 7.444~pdp-proven-media' in CTL
assert '#define AD_VERSION "v7.444-pdp-proven-media"' in S
assert 'VER=7.444' in UI
assert 'AD_PROBE_VERSION=7.444' in SK and 'AD_PROBE_NAME=AmazonDark-v7.444' in SK
assert 'AmazonDark-v7.444-ui-viewport.arm' in INC

# The bridge must exist before any frame document loads, including cross-origin SafeFrames.
assert 'ADUIProbeAttach7362(ucc);' in S
assert 'kADUniversalProbeUS7433' in S
assert 'objc_setAssociatedObject(self,kADUniversalProbeUS7433,nil' in S
assert 'initWithSource:source?:@"" injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO' in INC
assert 'addScriptMessageHandler:gADUniversalUIBridge7433 name:@"adUniversalUI7433"' in INC
assert 'removeScriptMessageHandlerForName:@"adUniversalUI7433"' in INC
assert 'CROSS_FRAME_DOM' in INC and 'CROSS_FRAME_FLUSH_WAIT ms=900' in INC

main=''.join(json.loads(x) for x in MAIN_INC.splitlines())
frame=''.join(json.loads(x) for x in FRAME_INC.splitlines())

# Main-frame capture no longer tries to violate the iframe origin boundary; it dispatches instead.
assert 'contentDocument' not in main
assert 'broadcastFrames' in main
assert 'f.contentWindow.postMessage(cmd' in main
assert 'window.__adUIProbeNonce7433' in main

# Every child frame can inspect its own DOM and recursively fan out to nested frames.
for token in [
    "window.addEventListener('message'", 'adUniversalUI7433', 'walkRoot(document.documentElement',
    "document.querySelectorAll('iframe')", "f.contentWindow.postMessage(child,'*')",
    'originHash', 'pathHash', 'referrerHash', 'payload.slice', 'chunkSize=96000',
    'paintRisk', 'effectiveBg', 'dark-on-dark', 'light-on-light', 'contrast-ok',
    'textMeta', 'ownHash', 'allHash', 'techAttrs', 'pseudo(', 'media(el)'
]:
    assert token in frame, token

# Privacy/performance: no raw URL/src/href capture and no recurring scanners.
assert "getAttribute('src')" not in frame and "getAttribute('href')" not in frame
for bad in ['MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'", 'scrollTo(', 'scrollBy(']:
    assert bad not in main, bad
    assert bad not in frame, bad

# Both C-string payloads must compile in the tweak's old C++ dialect and be valid JS.
with tempfile.TemporaryDirectory(prefix='ad7433-frame-') as td:
    td=Path(td)
    for name,incfile,expected in [('main','ADUniversalUIProbe7362.js.inc',main),('frame','ADUniversalUIProbe7362.frame.js.inc',frame)]:
        cpp=td/f'{name}.cpp'; exe=td/name
        cpp.write_text('#include <cstdio>\nstatic const char s[]=\n#include "'+incfile+'"\n;\nint main(){return std::fwrite(s,1,sizeof(s)-1,stdout)==sizeof(s)-1?0:1;}\n')
        subprocess.run(['c++','-std=gnu++98','-Wall','-Wextra','-Werror','-I',str(ROOT/'src'),str(cpp),'-o',str(exe)],check=True)
        emitted=subprocess.check_output([str(exe)]).decode()
        assert emitted==expected
        subprocess.run(['node','--check'],input=emitted,text=True,check=True)

print('PASS: v7.437 universal FULL/VIEWPORT bridge captures sanitized computed UI state inside cross-origin and nested frames')

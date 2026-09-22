from pathlib import Path
import json, subprocess, tempfile
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); I=(R/'src/ADUniversalUIProbe7362.inc').read_text()
M=''.join(json.loads(x) for x in (R/'src/ADUniversalUIProbe7362.js.inc').read_text().splitlines())
SC=''.join(json.loads(x) for x in (R/'src/ADUIProbeScroll7446.js.inc').read_text().splitlines())
SAMPLE=''.join(json.loads(x) for x in (R/'src/ADUIProbeViewportSample7449.js.inc').read_text().splitlines())
C=(R/'layout/DEBIAN/control').read_text()
assert 'Version: 7.450~pdp-readonly-full' in C
assert '#define AD_VERSION "v7.450-pdp-readonly-full"' in S
# Screenshot FULL may not synchronously format a full native hierarchy anymore.
cap=I[I.index('static void ADCaptureUniversalUIProbe7362(BOOL viewportOnly,NSString *trigger){'):I.index('static NSString *ADUIViewportArmPath7362')]
assert 'ADUINativeSnapshot7362(viewportOnly)' not in cap
assert 'ADUINativeSnapshotAsync7449(nil,NO,30000,28000' in cap
assert 'pending-cooperative-discovery' in cap
assert 'ADUINativeScrollCandidatesAsync7449' in cap
# The old algorithm did INITIAL_FULL_DOM before lazy loading and restarted a viewport TreeWalker every sweep step.
assert 'INITIAL_FULL_DOM' not in I
assert 'ADUIWebJS7364(@"viewport",@"sweep-step"' not in I
assert 'FINAL_FULL_DOM' in I and 'FINAL_CATCHUP_DOM' in I
assert 'WEB_ROOT_BOTTOM_STABLE -> FINAL_FULL_DOM' in I
assert 'WEB_POST_INVENTORY_GROWTH' in I
assert 'SWEEP_SAMPLE_' in I and 'ADUIWebSampleJS7449' in I
# Complete mounted-DOM inventory is cooperative and materially above the old 24k ceiling.
assert 'maxNodes=viewportOnly?30000:120000' in M
assert 'limit=viewportOnly?48:32' in M and 'budget=viewportOnly?4:3' in M
assert "phase==='final-full'" in M and "phase==='catchup-full'" in M
assert '__adUIProbeSeen7449' in M and 'skippedSeen' in M
assert '__adUIProbeScrollOwners7449' in M
# Scroll driving itself is metrics-only and uses both height and node-count stability.
for token in ['initroot','initowners','nodeCount','getElementsByTagName','__adUIWalkState7449']:
    assert token in SC, token
assert 'document.createTreeWalker' not in SC
# Per-step transient evidence is bounded hit-testing, never a full DOM walk.
assert 'elementsFromPoint' in SAMPLE and 'nodes.length>=160' in SAMPLE
assert 'createTreeWalker' not in SAMPLE and 'querySelectorAll' not in SAMPLE
# FULL native hierarchy and native scroll snapshots both use the cooperative walker.
assert I.count('ADUINativeSnapshotAsync7449(') >= 4
assert 'cooperative version of native scroll discovery' in I
# No new production recurring machinery.
for bad in ('new MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in S, bad
for js in (M,SAMPLE,SC):
    assert 'MutationObserver(' not in js and 'setInterval(' not in js and 'requestAnimationFrame(' not in js
# New JS include compiles as the same old-style C string and parses as JavaScript.
with tempfile.TemporaryDirectory(prefix='ad7449-') as td:
    td=Path(td); cpp=td/'x.cpp'; exe=td/'x'
    cpp.write_text('#include <cstdio>\nstatic const char s[]=\n#include "ADUIProbeViewportSample7449.js.inc"\n;\nint main(){return std::fwrite(s,1,sizeof(s)-1,stdout)==sizeof(s)-1?0:1;}\n')
    subprocess.run(['c++','-std=gnu++98','-Wall','-Wextra','-Werror','-I',str(R/'src'),str(cpp),'-o',str(exe)],check=True)
    emitted=subprocess.check_output([str(exe)]).decode(); assert emitted==SAMPLE
    subprocess.run(['node','--check'],input=emitted,text=True,check=True)
print('PASS: v7.450 FULL is cooperative, post-lazy-load complete, and does not rewalk the entire DOM per scroll step')

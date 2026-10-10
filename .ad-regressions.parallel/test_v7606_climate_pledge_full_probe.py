"""v7.606: probe-backed Octopus Climate Pledge page, screenshot FULL recovery."""
from pathlib import Path
import json, subprocess, tempfile
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text()
J=(R/'src/ADClimatePledge7606.js').read_text()
I=(R/'src/ADClimatePledge7606.js.inc').read_text()
P=(R/'src/ADUniversalUIProbe7362.inc').read_text()
G=(R/'src/ADPDPShareGate7456.js.inc').read_text()
assert ''.join(json.loads(line) for line in I.splitlines())==J
assert '#include "ADClimatePledge7606.js.inc"' in S
assert 'base=[base stringByAppendingString:climate606];' in S
assert '.octopus-page-style:has(.apb-default-category-drilldown)' in J
assert '.apb-default-category-drilldown>.a-box.a-vertical' in J
assert 'border-bottom-color:#494d4d' in J
assert 'border-color:#747a7c' in J
assert 'i.a-icon-touch-link' in J
assert 'border-color:#fff' in J
assert 'filter:brightness(__FACTOR__)' in J
assert 'background-blend-mode:multiply' in J
css=J.split('s.textContent=`',1)[1].split('`;',1)[0]
for bad in ('MutationObserver','setInterval','setTimeout','requestAnimationFrame','border-radius:','border-width:','width:','height:','::after','::before'):
 assert bad not in css,bad
assert 'screenshot-resumed-active' in P
assert 'gADPendingScreenshotFull7606=NO' in P
assert 'WEB_FULL_SHARE_GATE_FAILED generic-web' in P
assert "if(!pdp&&!share&&!locked)return {ready:true,reason:'generic-unlocked'};" in G
assert 'FULL_WEB_FIRST route=generic-web' in P
assert 'ADUIScanWebViewFull7364(wv,index,path,cap,nextWeb);' in P
with tempfile.TemporaryDirectory() as td:
 cpp=Path(td)/'include.cpp'
 cpp.write_text('static const char value[]=\n#include "ADClimatePledge7606.js.inc"\n;\nint main(){return sizeof(value)>400?0:1;}\n')
 subprocess.run(['c++','-std=gnu++98','-fsyntax-only','-I',str(R/'src'),str(cpp)],check=True)
 subprocess.run(['node','--check','-'],input=J.replace('__FACTOR__','0.58'),text=True,check=True)
print('PASS v7.606 exact Octopus DOM owners, no extra borders, valid JS/C++98; screenshot FULL recovery')

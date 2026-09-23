from pathlib import Path
import json,subprocess,tempfile
R=Path(__file__).resolve().parents[1]
I=(R/'src/ADUniversalUIProbe7362.inc').read_text()
T=(R/'src/Tweak.xm').read_text()
js=''.join(json.loads(x) for x in (R/'src/ADPDPShareGate7456.js.inc').read_text().splitlines())
assert 'close.click()' in js
for bad in ["classList.remove(",'.style.',"addEventListener('scroll'",'MutationObserver','setInterval','createTreeWalker']:
    assert bad not in js,bad
assert 'static NSString *ADShareProbeSuppressJS7403(void){return @"";}' in T
assert "if([result[@\"error\"] isEqualToString:@\"pdp-modal-locked\"])" in I
assert 'ADUIScanPDPManual7455' not in I
assert 'PDP_SHARE_GATE_TIMEOUT no-scroll-issued' in I
with tempfile.TemporaryDirectory() as d:
    p=Path(d); (p/'x.cpp').write_text('#include <cstdio>\nstatic const char s[]=\n#include "ADPDPShareGate7456.js.inc"\n;\nint main(){std::fwrite(s,1,sizeof(s)-1,stdout);}\n')
    subprocess.run(['c++','-std=gnu++98','-Wall','-Wextra','-Werror','-I',str(R/'src'),str(p/'x.cpp'),'-o',str(p/'x')],check=True)
    assert subprocess.check_output([str(p/'x')]).decode()==js
subprocess.run(['node','--check'],input=js,text=True,check=True)
subprocess.run(['node',str(R/'tests/probe_share_gate7456.cjs'),str(R)],check=True)

"""v7.605: reveal authored carbon-impact box corners, no synthetic border."""
from pathlib import Path
import json, subprocess, tempfile
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text()
J=(R/'src/ADSustainabilityBorder7605.js').read_text()
I=(R/'src/ADSustainabilityBorder7605.js.inc').read_text()
assert ''.join(json.loads(x) for x in I.splitlines())==J
assert '#include "ADSustainabilityBorder7605.js.inc"' in S
assert 'base=[base stringByAppendingString:sustain605];' in S
assert '#dp#dp #sustainability #climatePledgeFriendly .a-box.cpf-dpx-bottom-sheet-carousel-inner > .a-box-inner' in J
assert 'background:transparent!important' in J
assert 'box-shadow:none!important' in J
assert '#494d4d' in J and 'radius 15px' in J and 'radius 8px' in J  # probe documentary fact
# In the new CSS *no* attempt to add or manipulate borders and no geometry changes.
css=J.split('s.textContent=`',1)[1].split('`;',1)[0]
for forbidden in ('border:', 'border-color:', 'border-radius:', 'border-width:', 'outline:',
                  '::before','::after','clip-path:', 'overflow:', 'width:', 'height:',
                  'MutationObserver', 'querySelectorAll(', 'setInterval(', 'setTimeout(', 'requestAnimationFrame('):
 assert forbidden not in css,forbidden
assert not any(x in J for x in ('MutationObserver','querySelectorAll(', 'setInterval(', 'setTimeout('))
with tempfile.TemporaryDirectory() as td:
 c=Path(td)/'check.cpp'
 c.write_text('#include <stdio.h>\nstatic const char c[]=\n#include "ADSustainabilityBorder7605.js.inc"\n;\nint main(){return sizeof(c)>100?0:1;}\n')
 subprocess.run(['c++','-std=gnu++98','-fsyntax-only','-I',str(R/'src'),str(c)],check=True)
 subprocess.run(['node','--check','-'],input=J,text=True,check=True)
print('PASS: v7.605 carbon box inner ink made transparent, author border/radius retained; JS and C++98')

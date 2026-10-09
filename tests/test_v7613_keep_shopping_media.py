"""v7.613 targeted shopping-for image restore, text color, TWB and isolation."""
from pathlib import Path
import json, subprocess, tempfile
import tinycss2
R=Path(__file__).resolve().parents[1]
x=(R/'src/Tweak.xm').read_text()
a=(R/'src/ADKeepShopping7613.js').read_text()
i=(R/'src/ADKeepShopping7613.js.inc').read_text()
assert ''.join(json.loads(line) for line in i.splitlines())==a
assert '#define AD_VERSION "v7.613-keep-shopping-media"' in x
assert 'Version: 7.613~keep-shopping-media' in (R/'layout/DEBIAN/control').read_text()
assert '#include "ADKeepShopping7613.js.inc"' in x
assert 'base=[base stringByAppendingString:keepShopping7613];' in x
assert x.index('base=[base stringByAppendingString:saves7611];')<x.index('base=[base stringByAppendingString:keepShopping7613];')
for needle in ('/^keep shopping for\\s*:?$/i','media.length>=3','data-ad7613-keep-shopping-for','var owners=\':is(\'+scope','filter:'+"'"+'+tone','mix-blend-mode:normal','visibility:visible','opacity:1','background-image\',im,\'important\'','color:#fff!important','-webkit-text-fill-color:#fff!important'):
    assert needle in a, needle
for bad in ('MutationObserver','setInterval(','requestAnimationFrame(','scrollTo(','fetch(','new Image(','::before','::after','border-width:','border-radius:','position:fixed','display:none'):
    assert bad not in a,bad
with tempfile.TemporaryDirectory() as td:
    cpp=Path(td)/'include.cpp'
    cpp.write_text('#include <stdio.h>\nstatic const char js[] =\n#include "ADKeepShopping7613.js.inc"\n;\nint main(){return sizeof(js)>100?0:1;}\n')
    subprocess.run(['c++','-std=gnu++98','-I',str(R/'src'),'-fsyntax-only',str(cpp)],check=True)
for factor in ('0.58','1.0'):
    source=a.replace('__FACTOR__',factor)
    subprocess.run(['node','--check','-'],input=source,text=True,check=True)
    # The CSS must be descendant-scoped, not a naked comma-separated root rule.
    assert "var owners=':is('+scope+" in source
    assert 'ad7613-keep-shopping-for' in source
# Contrast with legacy carousel: no generic .a-carousel img changes.
assert '.a-carousel' not in a
assert 'document.querySelectorAll' not in a # exactly one bounded scoped document query, no recursive walker
print('PASS v7.613: exact-title-scoped media restoration, optional tame, white text, CSS isolation, gnu++98/JS')

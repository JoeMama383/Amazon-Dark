"""7.609 prove media background restoration (no image wiping) and exact sort popover CSS."""
from pathlib import Path
import json,re,subprocess,tempfile
import tinycss2
from lxml import html
from cssselect2 import ElementWrapper,compile_selector_list
R=Path(__file__).resolve().parents[1]
main=(R/'src/Tweak.xm').read_text()
inc=(R/'src/ADReviewBusiness7593.js.inc').read_text()
src=''.join(json.loads(line) for line in inc.splitlines())
js=(R/'src/ADReviewSortPopover7609.js').read_text()
include=''.join(json.loads(line) for line in (R/'src/ADReviewSortPopover7609.js.inc').read_text().splitlines())
assert include==js
assert '#include "ADReviewSortPopover7609.js.inc"' in main
assert main.index('base=[base stringByAppendingString:review7608];')<main.index('base=[base stringByAppendingString:reviewSort7609];')
assert 'Version: 7.619~handoff-regression-repair' in (R/'layout/DEBIAN/control').read_text()
# Verify the exact destructive base and later rules from 7.593/7.594 no longer
# set background-image:none or background:transparent on the media owner.
assert '.review-views,.review-image-thumbnail,.review-image-tile' not in src
photo_bg_reset=src.split('var css=`',1)[1].split('`;\n',1)[0]
assert '.review-views,.a-search' in photo_bg_reset
assert 'background-image:none!important' in photo_bg_reset  # only for STRUCTURAL panels
assert 'overflow:visible!important;background-color:transparent!important' in photo_bg_reset
assert 'overflow:visible!important;background:transparent!important' not in photo_bg_reset
assert 'button.review-image-thumbnail' in src
assert 'background-blend-mode:multiply!important' in src
assert 'ad7593MediaTone' in src and '__AD7593_FACTOR__' in src
# confirm CSS includes correct classes; preserve img filter for media carousel.
assert 'img:not([class*=logo])' in src and 'filter:brightness(__AD7593_FACTOR__)' in src
assert '.a-icon-close' in js and 'filter:brightness(0) invert(1)' in js
css=js.split('s.textContent=`',1)[1].split('`;',1)[0]
rules=[r for r in tinycss2.parse_rule_list(css,skip_whitespace=True,skip_comments=True) if r.type=='qualified-rule']
assert len(rules)==7,len(rules)
for rule in rules:
    sel=tinycss2.serialize(rule.prelude)
    assert ':has(.sort-order-option)' in sel
    ds=[d for d in tinycss2.parse_declaration_list(rule.content,skip_whitespace=True,skip_comments=True) if d.type=='declaration']
    assert ds and all(d.important for d in ds)
    assert all(d.name not in ('background','border','border-width','border-radius','width','height','transform') for d in ds)
assert '#2162a1' in css and '#000' in css and '#fff' in css and '#494d4d' in css
# Positive and unrelated negative popup fixtures from the viewport.
pos=html.fromstring('''<div id="a-popover-2" class="a-popover a-dropdown a-dropdown-common a-declarative">
<div class="a-popover-wrapper"><div class="a-popover-header a-declarative"><h4 class="a-popover-header-content">Sort</h4><button class="a-button-close"><i class="a-icon a-icon-close"></i></button></div>
<div class="a-popover-inner"><ul class="a-nostyle a-list-link"><li class="a-dropdown-item sort-order-option"><a id="sort-order-dropdown_0" role="option" class="a-dropdown-link a-active">Top reviews</a></li><li class="a-dropdown-item sort-order-option"><a id="sort-order-dropdown_1" role="option" class="a-dropdown-link">Most recent</a></li></ul></div></div></div>''')
neg=html.fromstring('<div id="a-popover-2" class="a-popover a-dropdown a-dropdown-common"><div class="a-popover-wrapper"><div class="a-popover-header"><button class="a-button-close"><i class="a-icon a-icon-close"></i></button></div></div></div>')
selectors=[tinycss2.serialize(r.prelude).strip() for r in rules]
for elid in ('sort-order-dropdown_0','sort-order-dropdown_1'):
    el=pos.get_element_by_id(elid)
    wrapper=next(n for n in ElementWrapper.from_html_root(pos).iter_subtree() if n.etree_element is el)
    assert any(any(c.test(wrapper) for c in compile_selector_list(sel)) for sel in selectors)
for node in ElementWrapper.from_html_root(neg).iter_subtree():
    assert not any(any(c.test(node) for c in compile_selector_list(sel)) for sel in selectors)
for prohibited in ('MutationObserver','querySelectorAll','setInterval','setTimeout','requestAnimationFrame','background-image:none','::before','::after'):
    assert prohibited not in js
# runtime JS CSS construction with configurable tone: verify no syntax regression.
subprocess.run(['node','--check','-'],input=js,text=True,check=True)
for f in ('0.42','1.0'):
    subprocess.run(['node','--check','-'],input=src.replace('__AD7593_FACTOR__',f).replace('__AD7593_ENABLED__','true'),text=True,check=True)
with tempfile.TemporaryDirectory() as td:
    p=Path(td)/'include_test.cpp'
    p.write_text('#include <stdio.h>\nstatic const char a[]=\n#include "ADReviewBusiness7593.js.inc"\n;\nstatic const char b[]=\n#include "ADReviewSortPopover7609.js.inc"\n;\nint main(){return sizeof(a)+sizeof(b)>100?0:1;}\n')
    subprocess.run(['c++','-std=gnu++98','-I',str(R/'src'),'-fsyntax-only',str(p)],check=True)
print('PASS v7.609: remove photo-image wiping; preserve CSS background/taming; exact OLED sort popup + blue selection; JS and gnu++98')

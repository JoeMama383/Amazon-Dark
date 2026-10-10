"""Regression for the exact reviews-filter-options popover neutral-button recolor."""
from pathlib import Path
import json, subprocess, tempfile
import tinycss2
from lxml import html
from cssselect2 import ElementWrapper, compile_selector_list

root=Path(__file__).resolve().parents[1]
s=(root/'src/Tweak.xm').read_text()
j=(root/'src/ADReviewFilterMenu7608.js').read_text()
i=(root/'src/ADReviewFilterMenu7608.js.inc').read_text()
assert ''.join(json.loads(x) for x in i.splitlines())==j
assert '#include "ADReviewFilterMenu7608.js.inc"' in s
assert 'base=[base stringByAppendingString:review7608];' in s
assert s.index('base=[base stringByAppendingString:pdp607];')<s.index('base=[base stringByAppendingString:review7608];')
assert 'Version: 7.619~handoff-regression-repair' in (root/'layout/DEBIAN/control').read_text()
css=j.split('s.textContent=`',1)[1].split('`;',1)[0]
rules=[r for r in tinycss2.parse_rule_list(css,skip_whitespace=True,skip_comments=True) if r.type=='qualified-rule']
assert len(rules)==7
for r in rules:
    decls=[d for d in tinycss2.parse_declaration_list(r.content,skip_whitespace=True,skip_comments=True) if d.type=='declaration']
    assert decls and all(d.important for d in decls)
# Minimal DOM transcribed from the supplied FULL probe.
doc=html.fromstring("""<html><body><div id='a-popover-1' class='a-popover a-popover-secondary a-declarative'><div class='a-popover-wrapper'><div class='a-popover-inner a-color-alternate-background'><div id='a-popover-content-1' class='a-container a-secondary-view-inner'><div id='reviews-filter-options-view'><span id='reviews-filter-options-clear' class='a-button a-button-disabled a-spacing-base a-button-base a-button-small'><span class='a-button-inner'><span id='reviews-filter-options-clear-announce' class='a-button-text'>Clear All</span></span></span><div class='a-row a-spacing-base'><div id='reviews-media-checkbox' class='a-box a-vertical a-touch-multi-select'><div class='a-box-inner a-padding-none'><ul class='a-nostyle a-box-list'><li class='a-list-item'><div class='a-touch-link a-touch-multi-select a-box-inner' role='checkbox'><span class='a-touch-multi-select-item-label'>Media</span><i class='a-icon a-icon-touch-multi-select-active'></i></div></li></ul></div></div></div><div class='a-row a-spacing-base'><div id='star-filter-select' class='a-box a-vertical'><div class='a-box-inner a-padding-none'><ul class='a-unordered-list a-nostyle a-box-list'><li class='a-list-item'><div class='a-touch-link a-box a-touch-link-noborder a-touch-select' role='button'><span class='a-text-bold'>Reviews for:</span><i class='a-icon a-icon-touch-select'></i></div></li></ul></div></div></div><span id='reviews-filter-options-apply' class='a-button a-spacing-base a-button-primary a-button-small'><span class='a-button-inner'><input class='a-button-input' type='submit'><span id='reviews-filter-options-apply-announce' class='a-button-text'>Apply</span></span></span></div></div></div></div></body></html>""")
root_node=ElementWrapper.from_html_root(doc)
all_nodes=list(root_node.iter_subtree())
selectors=[tinycss2.serialize(r.prelude).strip() for r in rules]
for target in ['reviews-filter-options-clear','reviews-filter-options-apply','reviews-media-checkbox','star-filter-select']:
    el=doc.get_element_by_id(target)
    wrapped=[n for n in all_nodes if n.etree_element is el][0]
    assert any(any(c.test(wrapped) for c in compile_selector_list(sel)) for sel in selectors), target
neg=html.fromstring("<div id='other'><span id='reviews-filter-options-apply' class='a-button a-button-primary'><span class='a-button-inner'><span class='a-button-text'>Apply</span></span></span></div>")
neg_node=ElementWrapper.from_html_root(neg)
neg_el=neg.get_element_by_id('reviews-filter-options-apply')
wrapped=[n for n in neg_node.iter_subtree() if n.etree_element is neg_el][0]
exact_button_selectors=[selectors[1],selectors[2],selectors[3],selectors[4]]
assert not any(any(c.test(wrapped) for c in compile_selector_list(sel)) for sel in exact_button_selectors)
for required in ['#303335','#747a7c','#494d4d','#000','#fff','reviews-filter-options-clear','reviews-filter-options-apply','star-filter-select']:
    assert required in j, required
for forbidden in ('MutationObserver','querySelectorAll','setInterval','setTimeout','requestAnimationFrame','filter:brightness(','scrollTo','border-radius','transform:','svg path'):
    assert forbidden not in j, forbidden
with tempfile.TemporaryDirectory() as t:
    p=Path(t)/'include_test.cpp'
    p.write_text('#include <stdio.h>\nstatic const char data[] =\n#include "ADReviewFilterMenu7608.js.inc"\n;\nint main(){return sizeof(data)>100?0:1;}\n')
    subprocess.run(['c++','-std=gnu++98','-I',str(root/'src'),'-fsyntax-only',str(p)],check=True)
subprocess.run(['node','--check','-'],input=j,text=True,check=True)
print('PASS: v7.608 exact review filter popover buttons recolored; sprites preserved; JS/C++98')

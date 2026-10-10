"""Regression for two actual 7.605 PDP VIEWPORT owners, without DOM scans."""
from pathlib import Path
import json, re, subprocess, tempfile
import tinycss2
from lxml import html
from cssselect2 import ElementWrapper, compile_selector_list

root=Path(__file__).resolve().parents[1]
s=(root/'src/Tweak.xm').read_text()
j=(root/'src/ADPDPLastMile7607.js').read_text()
i=(root/'src/ADPDPLastMile7607.js.inc').read_text()
assert ''.join(json.loads(x) for x in i.splitlines()) == j
assert '#include "ADPDPLastMile7607.js.inc"' in s
assert 'base=[base stringByAppendingString:pdp607];' in s
assert 'base=[base stringByAppendingString:climate606];' in s
assert s.index('base=[base stringByAppendingString:climate606];')<s.index('base=[base stringByAppendingString:pdp607];')
assert 'Version: 7.619~handoff-regression-repair' in (root/'layout/DEBIAN/control').read_text()

css=j.split('s.textContent=`',1)[1].split('`;',1)[0]
rules=[r for r in tinycss2.parse_rule_list(css,skip_whitespace=True,skip_comments=True) if r.type=='qualified-rule']
assert len(rules)==2
for r in rules:
 decls=tinycss2.parse_declaration_list(r.content,skip_whitespace=True,skip_comments=True)
 assert all(d.type=='declaration' and d.important for d in decls)
 assert all(d.name in ('color','-webkit-text-fill-color','border-bottom-color') for d in decls)

# Minimal DOM ancestors transcribed from supplied viewport traces; these
# selectors should not also match other recommendation, Prime and HOC blocks.
doc=html.fromstring('''<main id="dp">
 <div class="a-cardui-body"><a class="a-touch-link a-box a-touch-link-noborder">
 <span id="value-pick-title-view" class="a-size-base a-color-link">Blue title</span>
 <span id="value-pick-size-view" class="a-size-small a-text-bold">2 Count (Pack of 1)</span>
 <span class="value-pick-ac-badge-text-secondary">Choice</span></a></div>
 <div id="topHighlights"><hr class="a-divider-normal hoc-divider">
 <div id="nile-inline-insights_feature_div"><div class="dpx-insights-multi-row-carousel-container">
   <span>Summarized from product information</span></div></div></div>
 <div id="anotherWidget"><div class="dpx-insights-multi-row-carousel-container"></div></div>
</main>''')
root_node=ElementWrapper.from_html_root(doc)
all_nodes=list(root_node.iter_subtree())
matches=[]
for r in rules:
 sel=tinycss2.serialize(r.prelude).strip()
 compiled=compile_selector_list(sel)
 matched=[n.etree_element for n in all_nodes if any(x.test(n) for x in compiled)]
 matches.append(matched)
assert len(matches[0])==1 and matches[0][0].get('id')=='value-pick-size-view'
assert len(matches[1])==1 and 'dpx-insights' in matches[1][0].get('class')
assert '#b0b3b5' in tinycss2.serialize(rules[0].content)
assert '#494d4d' in tinycss2.serialize(rules[1].content)
for forbidden in ('MutationObserver','querySelectorAll','setInterval','setTimeout','requestAnimationFrame','border-radius','border-width','background:','::before','::after','scrollTo','filter:'):
 assert forbidden not in j,forbidden
with tempfile.TemporaryDirectory() as t:
 p=Path(t)/'include_test.cpp'
 p.write_text('#include <stdio.h>\nstatic const char data[]=\n#include "ADPDPLastMile7607.js.inc"\n;\nint main(){return sizeof(data)>100?0:1;}\n')
 subprocess.run(['c++','-std=gnu++98','-I',str(root/'src'),'-fsyntax-only',str(p)],check=True)
subprocess.run(['node','--check','-'],input=j,text=True,check=True)
print('PASS: 7.607 probe-exact count line and summary bottom-border colors; targeted CSS-only injection; JS/C++98')

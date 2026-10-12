"""Prove retained match sets and specificity, including after subtree changes."""
from pathlib import Path
import json,re
import cssselect2
from xml.etree import ElementTree as ET
r=Path(__file__).resolve().parents[1]
# The transform is an ancestor relation identity, not a route/name heuristic.
cases=[('body','#dp'),('body','.sheet'),('#a-page','#form'),('html','.product')]
for parent,witness in cases:
 old=f'{parent}:has({witness}) {witness}'
 new=f'{parent}:is(*,{witness}) {witness}'
 for tail in ['', ' span', ':not(.semantic)', ' > button', ':is(span,div)']:
  a=cssselect2.compile_selector_list(old+tail)[0];b=cssselect2.compile_selector_list(new+tail)[0]
  assert a.specificity==b.specificity,(old,new,a.specificity,b.specificity)
  for html in [
   '<html><body id="a-page"><div/><span/></body></html>',
   '<html><body id="a-page"><div id="dp" class="sheet"><span/><button/></div><span/></body></html>',
   '<html><body id="a-page"><div id="form" class="product"><div class="sheet semantic"><span/></div></div></body></html>',
   '<html><body id="a-page" class="sheet"><div class="product"><div id="dp"><span/></div></div><div class="sheet"><button/></div></body></html>'
  ]:
   nodes=list(cssselect2.ElementWrapper.from_html_root(ET.fromstring(html)).iter_subtree())
   assert [i for i,n in enumerate(nodes) if a.test(n)]==[i for i,n in enumerate(nodes) if b.test(n)],(old,new,html)
files=['ADListsRegistry7633.js','ADReviewBusiness7593.js.inc','ADNewMenus7482.js.inc','ADMenuFollowup7595.js.inc','ADReturnsTheme7480.js.inc']
count=0
for name in files:
 p=r/'src'/name;s=p.read_text()
 if name.endswith('.inc'):s=''.join(json.loads(l) for l in s.splitlines())
 pairs=re.findall(r'((?:body|html|#[\w-]+)):is\(\*,(#[\w-]+|\.[\w-]+)\)(\s+)\2(?=[\s.#:\[>{])',s)
 count+=len(pairs)
 if name.endswith('.js'):
  assert ''.join(json.loads(l) for l in p.with_suffix('.js.inc').read_text().splitlines())==s
assert count==54,count
print('PASS: 54 redundant ancestor lookups removed; match sets, dynamic subtree states and specificity preserved')

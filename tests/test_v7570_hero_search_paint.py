from pathlib import Path
import json, subprocess, tempfile
import tinycss2, cssselect2
from lxml import html
from payload_source import block, strings
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text()
J=''.join(json.loads(l) for l in (R/'src/ADNewMenus7482.js.inc').read_text().splitlines() if l.strip())
css=J.split('s.textContent=`',1)[1].split('`;',1)[0]
def match(css,fixture):
 m=cssselect2.Matcher()
 for rule in tinycss2.parse_stylesheet(css,skip_comments=True,skip_whitespace=True):
  if rule.type!='qualified-rule':continue
  try:sels=cssselect2.compile_selector_list(tinycss2.serialize(rule.prelude))
  except cssselect2.SelectorError:continue
  ds=[d for d in tinycss2.parse_declaration_list(rule.content) if d.type=='declaration']
  for s in sels:m.add_selector(s,ds)
 out={}
 for e in cssselect2.ElementWrapper.from_html_root(html.fromstring(fixture)).iter_subtree():
  wins={}
  for spec,order,pseudo,ds in m.match(e):
   if pseudo:continue
   for d in ds:
    k=(d.important,spec,order)
    if d.name not in wins or k>=wins[d.name][0]:wins[d.name]=(k,tinycss2.serialize(d.value).strip())
  if e.id:out[e.id]={k:v[1] for k,v in wins.items()}
 return out
out=match(css,'''<html><body><div class="s-mobile-toolbar"><a id="pill" class="sf-mobile-filter-element sf-mobile-filter-hve"><span id="label" class="a-color-base">Prime Big Deals</span></a><input id="switch" type="checkbox"/></div><li class="a-carousel-card"><div class="s-result-item s-asin"><div id="wrapper" class="s-product-image-container puis-image-overlay-grey"><img id="product"/></div></div></li></body></html>''')
assert out['pill']['background-color']=='#202324'
assert out['label']['color']==out['label']['-webkit-text-fill-color']=='#e8e6e3'
assert out['wrapper']['background-color']=='#000'
for prop in ('filter','width','padding','overflow'):assert prop not in out['wrapper']
assert 'filter' not in out['switch']
fmt=strings(block(T,'ADHomeCanvasMediaJS7570'))
fixture='''<html><body><div id="gwm-window"><div data-csa-c-painter="canvas-card-cards"><a class="canvas-image-link"><hp-background-image><amazon-image><picture><img id="hero"/></picture></amazon-image></hp-background-image></a><div class="feature-overlay"><h2 id="title">Deals</h2><button id="hotspot">View</button></div></div><img id="other"/></div></body></html>'''
for f in (1.,.9,.684,.42):
 js=fmt%(f,f)
 with tempfile.NamedTemporaryFile(suffix='.js',mode='w') as p:
  p.write(js);p.flush();subprocess.run(['node','--check',p.name],check=True,capture_output=True)
 out=match(js.split("s.textContent='",1)[1].split("';",1)[0],fixture)
 assert out['hero']['filter']=='brightness(%.3f)'%f
 for n in ('title','hotspot','other'):assert not out[n],(n,out[n])
print('PASS: captured canvas hero artwork dims at preference bounds; overlay controls preserved; Search HVE text and image side floors corrected')

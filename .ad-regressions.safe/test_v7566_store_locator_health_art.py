from pathlib import Path
import json,subprocess,tempfile
from payload_source import block,strings
import tinycss2,cssselect2
from lxml import html
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text()
J=''.join(json.loads(l) for l in (R/'src/ADNewMenus7482.js.inc').read_text().splitlines() if l.strip())
css=J.split('s.textContent=`',1)[1].split('`;',1)[0]
fixture='''<html><body><div class="aplf-list-view-with-map"><div id="aplf-map-container-mobile"><canvas class="mapboxgl-canvas"/><div class="map-marker" id="pin"/></div><div class="aplf-list-content-overlay" id="floor"><h5 id="name">Store</h5><span class="a-color-success" id="open">Open</span><a id="phone"><span id="phonecopy">Phone</span></a><div class="aplf-searchbar-icon"><svg><path id="Union"/></svg></div><div class="directions-button"><svg><path id="Arrow"/></svg></div><div class="list-filter-button" id="pill"/><span class="a-button a-button-primary" id="button"><span class="a-button-inner"><span class="a-button-text" id="buttontext"/></span></span></div></div><div id="outside"/></body></html>'''
m=cssselect2.Matcher()
for rule in tinycss2.parse_stylesheet(css,skip_comments=True,skip_whitespace=True):
 if rule.type!='qualified-rule':continue
 try:sels=cssselect2.compile_selector_list(tinycss2.serialize(rule.prelude))
 except cssselect2.SelectorError:continue
 ds=[d for d in tinycss2.parse_declaration_list(rule.content) if d.type=='declaration']
 for sel in sels:m.add_selector(sel,ds)
styles={}
for e in cssselect2.ElementWrapper.from_html_root(html.fromstring(fixture)).iter_subtree():
 wins={}
 for spec,order,pseudo,ds in m.match(e):
  if pseudo:continue
  for d in ds:
   key=(d.important,spec,order)
   if d.name not in wins or key>=wins[d.name][0]:wins[d.name]=(key,tinycss2.serialize(d.value).strip())
 if e.id:styles[e.id]={k:v[1] for k,v in wins.items()}
assert styles['floor']['background']=='#000'
assert styles['name']['color']=='#fff'
assert 'color' not in styles['open'] and 'color' not in styles['phonecopy']
assert styles['Union']['fill']=='#fff' and styles['Arrow']['fill']=='#fff'
assert styles['pill']['background']=='#303335'
assert styles['button']['background']=='#000' and styles['buttontext']['color']=='#fff'
assert styles['pin']['box-shadow']=='none'
assert 'background' not in styles['outside']
b=block(T,'ADStoreMapMediaJS7566');fmt=strings(b)
for f in (1.0,.9,.684,.42):
 js=fmt%(f,f)
 with tempfile.NamedTemporaryFile(suffix='.js',mode='w') as p:
  p.write(js);p.flush();subprocess.run(['node','--check',p.name],check=True,capture_output=True)
 assert 'brightness(%.3f)'%f in js
 assert '.mapboxgl-canvas' in js and 'filter:none!important' in js
I=(R/'src/ADServiceSheetImages7565.inc').read_text()
section=I[I.index('if(glyph||logo||banner)'):I.index('}else if(w>=52')]
assert 'ADMenuRemoveTWB7255(iv)' in section
assert 'ADEnsureNativeTWBOverlay7270' not in section
assert 'ADServiceLogo7565(original,banner)' in section
assert 'ADEnsureNativeTWBOverlay7270' in I[I.index('}else if(w>=52'):]
print('PASS: Store locator OLED/white/gray cascade, preserved semantic colors, pin shadow removal, whole-map strength bounds and untamed Health AI art')

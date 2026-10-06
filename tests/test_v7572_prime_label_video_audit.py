from pathlib import Path
import json
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
  if rule.type!='qualified-rule': continue
  try: sels=cssselect2.compile_selector_list(tinycss2.serialize(rule.prelude))
  except cssselect2.SelectorError: continue
  ds=[d for d in tinycss2.parse_declaration_list(rule.content) if d.type=='declaration']
  for sel in sels: m.add_selector(sel,ds)
 out={}
 for e in cssselect2.ElementWrapper.from_html_root(html.fromstring(fixture)).iter_subtree():
  wins={}
  for spec,order,pseudo,ds in m.match(e):
   if pseudo: continue
   for d in ds:
    k=(d.important,spec,order)
    if d.name not in wins or k>=wins[d.name][0]: wins[d.name]=(k,tinycss2.serialize(d.value).strip())
  if e.id: out[e.id]={k:v[1] for k,v in wins.items()}
 return out
fixture="""<html><body><div id='search'><div class='sf-rib-row'><div class='sf-rib-column'><div class='a-section sf-rib-element'><span class='a-declarative'><a id='hve' class='a-link-normal sf-mobile-filter-element sf-filter-floatbox sf-mobile-filter-hve-layout sf-mobile-filter-hve'><span id='label' class='a-size-small a-color-base'>Prime Big Deals</span></a></span></div></div></div></div></body></html>"""
out=match(css,fixture)
assert out['label']['color']=='#fff'
assert out['label']['-webkit-text-fill-color']=='#fff'
# v7.571 viewport proved the real video is loaded and visible; retain non-destructive media policy.
floor=strings(block(T,'ADFloorJS'))
twb=strings(block(T,'ADTWBJS'))
for token in ('video.sbv-video-player-ecx','video._c2Itd_video_17g-f'):
 assert token in floor
 assert token in twb
assert 'filter:none!important;-webkit-filter:none!important' in floor
assert 'video._c2Itd_video_17g-f{filter:none!important;-webkit-filter:none!important;}' in twb
print('PASS: captured Prime Big Deals label is white without requiring the obsolete toolbar ancestor')
print('PASS: captured loaded Search video remains visible/unfiltered; no poster/playback behavior is rewritten')

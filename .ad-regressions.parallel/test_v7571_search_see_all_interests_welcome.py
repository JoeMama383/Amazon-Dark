from pathlib import Path
import json
import tinycss2, cssselect2
from lxml import html
R=Path(__file__).resolve().parents[1]
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
search="""<html><body><div id='search'><div class='s-breeze-see-all-container'><span id='seeall' class='a-button a-button-base a-button-small'><span id='inner' class='a-button-inner'><a id='label' class='a-button-text'><span id='copy' class='a-size-small'>See all</span><i id='chevron' class='a-icon a-icon-arrow a-icon-small'></i></a></span></span></div><div class='outside'><span id='outside' class='a-button a-button-base a-button-small'></span></div></div></body></html>"""
out=match(css,search)
assert out['seeall']['background']=='#000'
assert out['seeall']['border']=='1px solid #747a7c'
assert out['inner']['background']=='transparent'
assert out['label']['color']==out['copy']['color']=='#fff'
assert out['chevron']['filter']=='brightness(0) invert(1)'
assert 'background' not in out['outside']
interest="""<html><body><div class='a-sheet-web-container' id='web'><div class='a-sheet-web' id='sheet'><div class='a-sheet-content-container' id='content'><div id='welcome' class='a-section _bW9ia_bottom-sheet_30aDp _bW9ia_auto-creation-new-customers-bottom-sheet_2d0vA _bW9ia_flex_1y7Kp'><div class='_bW9ia_tab-area_38yf-' id='tab'><div id='sheet-title-pdicqc' class='_bW9ia_title-container_19DuT'><span id='title' class='_bW9ia_title_1gskc'>Welcome to Interests</span><img id='titleimg' class='_bW9ia_title-image_38yXt'/><i id='close' class='a-icon a-icon-close _bW9ia_close-icon_3w-DL'></i></div></div><div id='wrap' class='_bW9ia_content-wrapper_3UjcO'><div class='_bW9ia_bottom-sheet-section_13aLR'><div id='row1' class='_bW9ia_bottom-sheet-row_e0TEk'>We're tracking Interests <img id='sparkle' class='_bW9ia_orange-sparkle-style_3sDE6'/></div><div id='row2' class='_bW9ia_bottom-sheet-row_e0TEk'>We'll keep searching</div></div></div></div></div></div></div></body></html>"""
out=match(css,interest)
for k in ('web','sheet','content','welcome','tab','wrap','row1','row2'):
 assert out[k].get('background')=='#000', (k,out[k])
 assert out[k].get('background-image')=='none', (k,out[k])
assert out['title']['color']==out['title']['-webkit-text-fill-color']=='#fff'
assert out['row1']['color']==out['row2']['color']=='#fff'
assert out['titleimg']['filter']==out['close']['filter']=='brightness(0) invert(1)'
assert out['sparkle']['filter']=='none' and out['sparkle']['opacity']=='1'
assert '._bW9ia_content-wrapper_3UjcO)::after{background:transparent!important' in css
print('PASS: Search see-all button uses OLED/gray/white treatment and Interests welcome sheet is full OLED with white copy/close/header while orange sparkle artwork is preserved')

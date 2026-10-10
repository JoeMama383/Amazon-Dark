from pathlib import Path
import tinycss2, cssselect2
from lxml import html
from payload_source import block, strings
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text()
fmt=strings(block(T,'ADPDPFollowupMediaJS7573'))
factor=.42
js=fmt%(factor,factor)
css=js.split('s.textContent=`',1)[1].split('`;',1)[0]

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

fixture="""<html><body><div id='dp'>
<div class='_p13n-mobile-sims-multi-bundle_multi-bundle-mobile_image-display__abc'><img id='multi' class='p13n-product-image'/></div>
<div class='_p13n-mobile-sims-fbt_fbt-mobile_image-display__def'><img id='fbt' class='p13n-product-image'/></div>
<div id='aw-udpv3-customer-reviews_feature_div'><button id='review' class='dpx-reviews-pill'><span id='reviewText'>Summarize 5-star reviews</span></button></div>
<div id='ape_detail_btf_mshop_placement'><div id='badge' class='_single-video-ads-card_style_sponsoredBadge__22nHz'><span id='sponsoredText'>Sponsored</span><b id='infoGlyph'>i</b></div><video id='video' class='_single-video-ads-card_style_video__17g-f'></video></div>
</div></body></html>"""
out=match(css,fixture)
for image_id in ('multi','fbt'):
 assert out[image_id]['filter']=='brightness(0.420)'
 assert out[image_id]['-webkit-filter']=='brightness(0.420)'
 assert out[image_id]['opacity']=='1'
 assert out[image_id]['visibility']=='visible'
 assert out[image_id]['mix-blend-mode']=='normal'
assert out['review']['background']=='#303335'
assert out['review']['border']=='1px solid #747a7c'
assert out['review']['border-color']=='#747a7c'
assert out['review']['color']==out['review']['-webkit-text-fill-color']=='#fff'
assert out['reviewText']['color']==out['reviewText']['-webkit-text-fill-color']=='#fff'
assert out['badge']['background']=='rgba(0,0,0,.9)'
# The request is container-only: text/glyph/video must receive no new declarations here.
assert not out['sponsoredText']
assert not out['infoGlyph']
assert not out['video']
assert '_single-video-ads-card_style_video__17g-f' not in css
print('PASS: PDP Customers-also-bought and FBT image families receive preference brightness without hiding images')
print('PASS: captured review-summary pills are gray with gray borders and white text')
print('PASS: lower video sponsored badge alone is inverted to 90% black; sponsored text, info glyph, and video are untouched')

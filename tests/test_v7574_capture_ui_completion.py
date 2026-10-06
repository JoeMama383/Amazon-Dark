from pathlib import Path
import json,subprocess,tempfile
import tinycss2,cssselect2
from lxml import html
from payload_source import block,strings
R=Path(__file__).resolve().parents[1];T=(R/'src/Tweak.xm').read_text()
J=''.join(json.loads(l) for l in (R/'src/ADNewMenus7482.js.inc').read_text().splitlines() if l.strip())
CSS=J.split('s.textContent=`',1)[1].split('`;',1)[0]
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

fixture='<html><body><div id="dp"><button id="review" class="dpx-reviews-pill">Summarize</button>\n<div class="_single-video-ads-card_style_videoAsinCard__DP-n0">\n<div id="pill" class="_single-video-ads-card_style_sponsoredBadge__22nHz"><span id="sponsored" class="_single-video-ads-card_style_ad-feedback-text__2HjQ9"><b id="info" class="_single-video-ads-card_style_ad-feedback-sprite-mobile__2_rj8"/></span></div>\n<video id="video" class="_single-video-ads-card_style_video__17g-f"/>\n<div class="_single-video-ads-card_style_productImage__22IPX" id="imagefloor"><img id="thumb"/></div>\n<span class="_single-video-ads-card_style_title__5uvT2"><span id="title" class="a-truncate-cut">Description</span></span>\n<span id="deal" class="_single-video-ads-card_style_dealBadge__2_eVb">39% off</span><span id="price" class="a-price">$23</span><i id="prime" class="a-icon-prime"/>\n</div>\n<div id="olpLinkWidget_feature_div"><a class="olp-touch-link"><span class="a-price"><span id="sellerprice" class="a-price-whole">40</span></span></a></div>\n<details id="ad7380-price-history"><a><img id="keepa"/></a><a><img id="camel"/></a></details>\n<div id="sims-multiProductBundle_feature_div_0"><div class="_p13n-mobile-sims-multi-bundle_multi-bundle-mobile_image-display__test"><img id="bundle" class="p13n-product-image"/></div></div>\n<div class="_p13n-mobile-sims-fbt_fbt-mobile_image-display__test"><img id="fbt" class="p13n-product-image"/><i id="plus"/></div>\n</div><div id="PCPO-slot-3" class="events-pcpo-placeholder-widget"><div data-csa-c-painter="pcpo-offer-cards"><img id="category" class="_pcpo-offer_style_imageclass__1FV5p"/><div id="categorylabel" class="_pcpo-offer_style_headingclass__1qi8s">Pets</div></div></div>\n<img id="banner" class="_hve-rankable-banner_style_bannerImage__18bYG"/><img id="unrelated"/>\n<div id="search"><a class="sf-mobile-filter-element sf-mobile-filter-hve"><span id="primelabel" class="a-size-small a-color-base">Prime Big Deals</span></a></div>\n</body></html>'
out=match(CSS,fixture)
assert out['review']['background']=='#303335' and out['review']['border']=='1px solid #747a7c'
assert out['review']['color']==out['review']['-webkit-text-fill-color']=='#fff'
assert out['pill']['background-color']=='rgba(0,0,0,.9)'
for k in ('sponsored','info','video','deal','price','prime'):
 delta=CSS.split('/* v7.574:',1)[1].split('/*',1)[0]
 assert not match(delta,fixture)[k],(k,match(delta,fixture)[k])
for k in ('title','sellerprice','primelabel'):assert out[k]['color']==out[k]['-webkit-text-fill-color']=='#fff',(k,out[k])
assert out['imagefloor']['mix-blend-mode']=='normal'
assert out['PCPO-slot-3']['background']=='#000'
fmt=strings(block(T,'ADCapturedMediaJS7574'))
legacy=strings(block(T,'ADPDPUICompletionJS7439'))
legacycss=legacy.split('s.textContent=`',1)[1].split('`',1)[0]
for factor in (1.,.9,.684,.42):
 js=fmt%(factor,factor)
 with tempfile.NamedTemporaryFile(mode='w',suffix='.js') as f:
  f.write(js);f.flush();subprocess.run(['node','--check',f.name],check=True,capture_output=True)
 media=js.split("s.textContent='",1)[1].split("';",1)[0]
 # Legacy visibility reset delivered before OR after the new leaf rule must not cancel dimming.
 for rules in (legacycss+media,media+legacycss):
  out=match(rules,fixture)
  for k in ('thumb','keepa','camel','bundle','fbt','category','banner'):
   assert out[k]['filter']=='brightness(%.3f)'%factor,(factor,k,out[k])
   assert out[k]['mix-blend-mode']=='normal'
  for k in ('plus','video','unrelated','categorylabel','sponsored','info','price','prime'):
   assert out[k]==match(legacycss,fixture)[k],(k,out[k])
assert 'MutationObserver' not in fmt and 'setInterval' not in fmt and 'requestAnimationFrame' not in fmt
print('PASS: captured bundle/chart/Prime imagery uses one preference-controlled leaf filter, survives legacy visibility reset, and preserves semantic paint; review buttons, Sponsored alpha, ad description and seller price corrected')

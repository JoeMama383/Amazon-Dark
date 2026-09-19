from pathlib import Path
import json,subprocess,sys
try:
 import tinycss2,cssselect2
 from lxml import html
except ImportError:
 print('SKIP: CSS cascade fixture requires tinycss2, cssselect2, lxml');sys.exit(0)
from payload_source import block,strings
ROOT=Path(__file__).resolve().parents[1]
src=(ROOT/'src/Tweak.xm').read_text();js=strings(block(src,'ADPDPCompletionJS7405'))
runner="const vm=require('vm');let css={};let d={referrer:'https://www.amazon.com/dp/B000000001',head:{appendChild(s){css[s.id]=s}},getElementById(id){return css[id]},createElement(){return {}}};let w={};w.top=process.argv[2]==='child'?{}:w;vm.runInNewContext(process.argv[1],{document:d,window:w});console.log(JSON.stringify(Object.values(css).map(s=>s.textContent).join('')));"
def sheet(child=False):
 return json.loads(subprocess.check_output(['node','-e',runner,js,'child' if child else 'main'],text=True))
def cascade(css,fixture):
 matcher=cssselect2.Matcher()
 for rule in tinycss2.parse_stylesheet(css,skip_comments=True,skip_whitespace=True):
  assert rule.type=='qualified-rule',rule
  selectors=cssselect2.compile_selector_list(rule.prelude)
  decls=[x for x in tinycss2.parse_declaration_list(rule.content,skip_comments=True,skip_whitespace=True) if x.type=='declaration']
  for selector in selectors:matcher.add_selector(selector,decls)
 out={}
 for node in cssselect2.ElementWrapper.from_html_root(html.fromstring(fixture)).iter_subtree():
  winners={}
  for specificity,order,pseudo,decls in matcher.match(node):
   if pseudo:continue
   for dec in decls:
    key=(dec.important,specificity,order);value=tinycss2.serialize(dec.value).strip()
    if key>=winners.get(dec.name,((-1,),''))[0]:winners[dec.name]=(key,value)
  if node.id:out[node.id]={k:v for k,(_,v) in winners.items()}
 return out
fixture='''<html><body><div id="dp">
<div id="hmod-swatch-list"><span id="ways" class="a-button a-button-toggle hmod-swatch-button"><span class="a-button-inner"></span></span></div>
<div id="mapleAdvertisement_feature_div"><div id="gift" class="maple-banner__container"><a class="a-link-normal"><span id="gifttext" class="maple-banner__text">Get a Gift Card <strong id="giftbold">upon approval</strong><span id="bluelink" class="a-color-link"><ins id="blueins">Learn more</ins></span></span></a></div></div>
<a class="starRating"><div id="cm_cr_dp_ma_rating_histogram"><h2 id="reviews">Customer reviews</h2><span id="rating" class="a-text-beside-button">4.4 out of 5</span><i id="stars" class="a-icon-star"></i></div></a>
<div id="mosaic" class="_c3Atb_image-display-small_3Hzcj"><img id="product"></div><div class="_rufus-comparison-card_style_cardImage__1AB2E"><img id="comparison"></div>
<span id="dpx-rex-nile-submit-button" class="a-button a-button-search"><span id="submitinner" class="a-button-inner"><button class="a-button-text"></button></span></span>
</div></body></html>'''
v=cascade(sheet(),fixture)
assert v['ways']['background']=='#000'
assert v['gift']['background']=='#000'
assert v['gifttext']['color']==v['giftbold']['color']=='#fff'
assert 'color' not in v['bluelink'] and v['blueins'].get('-webkit-text-fill-color')=='currentColor',v['bluelink']
assert v['reviews']['color']==v['rating']['color']=='#fff'
assert 'color' not in v['stars'],v['stars']
for id in ['mosaic','product','comparison']:assert v[id]['mix-blend-mode']=='normal'
for id in ['dpx-rex-nile-submit-button','submitinner']:assert v[id]['border']=='0' and v[id]['background']=='transparent',v[id]
child='''<html><body><div id="ad"><a id="title" data-id="product-name-text">Product</a><div id="caption" class="product-info"><span id="red" class="a-color-price">$1397</span><span id="prime" data-testid="prime-badge"><svg></svg></span></div></div></body></html>'''
v=cascade(sheet(True),child)
assert v['title']['color']=='#fff'
assert v['caption']['background-color']=='#000'
assert 'color' not in v['red'],v['red']
assert v['red']['-webkit-text-fill-color']=='currentColor'
print('PASS: probe-family CSS cascade restores media blend, neutral text, OLED floors and unboxed arrow; preserves blue/red/star paint')

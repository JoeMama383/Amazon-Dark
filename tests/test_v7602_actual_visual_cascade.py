"""Replay captured owners against production sheets, including older conflicting rules."""
import json,re,subprocess
from pathlib import Path
import cssselect2,tinycss2
from lxml import etree
from payload_source import block,strings
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text()
F=json.loads((R/'tests/fixtures/v7602_actual_visual_owners.json').read_text())
runner=r'''const fs=require('fs'),vm=require('vm');let sheets={};let d={referrer:'',readyState:'complete',querySelector(){return null},querySelectorAll(){return []},getElementById(id){return sheets[id]||null},createElement(){return {setAttribute(){}}},head:{appendChild(s){sheets[s.id]=s}},documentElement:{style:{setProperty(){}},setAttribute(){}},body:{style:{setProperty(){}}}};let w={addEventListener(){}};w.top=w;let errors=[];for(let js of JSON.parse(fs.readFileSync(0,'utf8'))){try{vm.runInNewContext(js,{document:d,window:w,location:{hostname:'www.amazon.com',pathname:'/dp/test'},console})}catch(e){errors.push(String(e))}};console.log(JSON.stringify({sheets:Object.fromEntries(Object.entries(sheets).map(([id,s])=>[id,s.textContent||''])),errors}));'''
js=[]
for name in ('ADFloorJS','ADPDPCompletionJS7405','ADPDPUICompletionJS7439','ADPDPMainResidualJS7440'):
 js.append(strings(block(S,name)))
for name in ('ADNewMenus7482.js.inc','ADReviewBusiness7593.js.inc','ADMenuFollowup7595.js.inc','ADPDPMenuFollowup7600.js.inc','ADPDPProbeOwners7601.js.inc','ADPDPVisualRepair7602.js.inc'):
 v=''.join(json.loads(l) for l in (R/'src'/name).read_text().splitlines())
 v=v.replace('__FACTOR__','0.420').replace('__AD7593_FACTOR__','0.420').replace('__AD7593_ENABLED__','true').replace('__AD7595_FACTOR__','0.420').replace('__AD7595_ENABLED__','true')
 js.append(v)
result=json.loads(subprocess.check_output(['node','-e',runner],input=json.dumps(js),text=True))
assert not result['errors'],result['errors']
assert result['sheets']['ad7602-pdp-visual-repair']
assert result['sheets']['ad7439-pdp-ui-completion']
matcher=cssselect2.Matcher()
for css in result['sheets'].values():
 for rule in tinycss2.parse_stylesheet(css,skip_comments=True,skip_whitespace=True):
  if rule.type!='qualified-rule':continue
  try:sels=cssselect2.compile_selector_list(rule.prelude)
  except cssselect2.SelectorError:continue # legacy WebKit-only selectors
  ds=[d for d in tinycss2.parse_declaration_list(rule.content) if d.type=='declaration']
  for sel in sels:matcher.add_selector(sel,ds)
def style(key):
 n=F[key];parent=None;root=None
 for token in reversed(n['chain'].split('<-')):
  m=re.match(r'^([a-zA-Z][\w-]*)(?:#([\w-]+))?((?:\.[\w-]+)*)',token)
  if not m:continue
  tag,ident,cl=m.groups();e=etree.Element(tag)
  if ident:e.set('id',ident)
  if cl:e.set('class',cl.lstrip('.').replace('.',' '))
  if parent is not None:parent.append(e)
  else:root=e
  parent=e
 for k,v in n.get('attrs',{}).items():parent.set(k,str(v))
 if key!='review_header':
  # All these PDP owners have their #dp ancestor independently recorded by FULL.
  dp=etree.Element('div',id='dp');dp.append(root);root=dp
 h=etree.Element('html');b=etree.SubElement(h,'body');b.append(root)
 leaf=next(w for w in cssselect2.ElementWrapper.from_html_root(h).iter_subtree() if w.etree_element is parent)
 wins={}
 for spec,order,pseudo,ds in matcher.match(leaf):
  if pseudo:continue
  for d in ds:
   val=tinycss2.serialize(d.value).strip();rank=(d.important,spec,order)
   props=[d.lower_name]
   if d.lower_name=='background':props+=['background-color']
   if d.lower_name=='border':props+=['border-top-width']
   for prop in props:
    if prop not in wins or rank>=wins[prop][0]:wins[prop]=(rank,val)
 return {k:v for k,(_,v) in wins.items()}
assert F['fbt_untamed']['filter']=='none'
assert style('fbt_untamed')['filter']=='brightness(0.420)',style('fbt_untamed')
assert style('fbt_first_card')['filter']=='brightness(0.420)',style('fbt_first_card')
for k in ('buy_label','buy_price','plus_wrapper'):
 assert style(k)['background-color']=='transparent',(k,style(k))
assert style('plus_button')['background-color']=='#303335'
assert F['similar_parent']['blend']=='multiply'
assert style('similar_parent')['mix-blend-mode']=='normal'
assert F['similar_image']['media']['complete'] and F['similar_image']['media']['naturalW']>0
assert style('similar_image')['filter']=='brightness(0.420)'
assert F['cart_button']['bg']=='rgb(255, 216, 20)'
assert style('cart_button')['background-color']=='#000'
assert style('cart_button')['border']=='1px solid #747a7c'
assert style('cart_label')['color']=='#fff'
assert style('cart_label')['background-color']=='transparent'
assert F['review_header']['color']=='rgb(15, 17, 17)'
assert style('review_header')['color']==style('review_header')['-webkit-text-fill-color']=='#fff'
# The repair does not recolor badges, or change layout geometry or load image URLs.
repair=(R/'src/ADPDPVisualRepair7602.js').read_text()
assert ''.join(json.loads(l) for l in (R/'src/ADPDPVisualRepair7602.js.inc').read_text().splitlines())==repair
for token in ('MutationObserver','setInterval','requestAnimationFrame','setTimeout','querySelectorAll','getAttribute','setAttribute'):
 assert token not in repair,token
css=result['sheets']['ad7602-pdp-visual-repair']
assert not re.search(r'(?:^|[;{])\s*(?:width|height|padding|margin|display|position|border-radius)\s*:',css)
assert '_cDEzb_best-seller_' not in css
assert 'ADPDPVisualRepair7602.js.inc' in S and 'stringByAppendingString:visualRepair602' in S
print('PASS: v7.602 real captured owners win against legacy CSS: FBT filter, transparent buy label/price and plus wrapper, multiply parent, OLED CTA, bare review h4; no layout/runtime scanning changes')

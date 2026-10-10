"""Probe-backed follow-up for the add-to-cart sheet, IOU card, bundle card and complementary plus buttons."""
from pathlib import Path
import json,subprocess
import tinycss2,cssselect2
from lxml import html
R=Path(__file__).resolve().parents[1]
js=(R/'src/ADPDPMenuFollowup7600.js').read_text()
assert ''.join(json.loads(x) for x in (R/'src/ADPDPMenuFollowup7600.js.inc').read_text().splitlines())==js
source=(R/'src/Tweak.xm').read_text()
assert '#include "ADPDPMenuFollowup7600.js.inc"' in source
assert 'pdp600=[pdp600 stringByReplacingOccurrencesOfString:@"__FACTOR__" withString:[NSString stringWithFormat:@"%.3f",(gP.whiteTame?ad7593Factor:1.0)]]' in source
assert 'MutationObserver' not in js and 'setInterval' not in js and 'requestAnimationFrame' not in js
fixture='''<html><body>
<div id="dp">
  <div id="ax-mbs"><div id="ax-mbs-content"><div id="sw-mbs" class="a-container a-color-alternate-background full-view-container"><div class="full-view"><div id="sw-mbs-recs"><div id="card" class="a-cardui sw-card-container"><span id="desc" class="a-color-secondary">gray descriptive copy</span><a id="link" class="a-link-normal">link</a><div class="tpb-progress-bar-label" id="goal">$25</div><button id="overlay-btn" name="submit.addToCart" class="add-to-cart-button"><span id="overlay-btn-text">Add to cart</span></button><a class="a-expander-header" id="see-more"><i id="overlay-chevron" class="a-icon a-icon-extender-expand"></i><span class="a-expander-prompt">See more</span></a><img id="overlay-image" class="sc-product-image"/></div><hr id="overlay-divider"/></div></div></div></div>
  <div id="instantOrderUpdate_feature_div"><article class="iou-card"><section id="iou" class="iou-card-inner"><section class="iou-card-main"><section class="iou-card-main__left"><h4 id="iou-date">Nov 14, 2025 <a id="iou-link">details</a></h4></section><section class="iou-card-main__right"><span class="a-price" id="iou-price"><span class="a-price-whole" id="iou-whole">9</span></span><span class="a-button a-button-primary atc-button" id="iou-button"><span class="a-button-inner"><input id="add-to-cart-button"/><span class="a-button-text"><div class="atc-button-text" id="iou-btn-text">Add to cart</div></span></span></span></section></section></section></article></div>
  <div id="multi-bundle-container-t3_feature_div"><div id="multi-bundle-card-grid-view" class="a-cardui"><div class="a-cardui-body multi-bundle-card-body"><h3 id="bundle-title">Frequently bought together</h3><div class="a-divider" id="bundle-divider"></div><img id="bundle-image" class="a-dynamic-image p13n-product-image"/></div></div></div>
  <div class="mosaic-atc-container"><div class="atc-spot-button-container"><button id="plus-btn" class="add-to-cart-button"><span id="plus-wrap"><span id="plus-icon" class="a-icon a-icon-small-add"></span></span></button></div></div>
  <i id="prime" class="a-icon-prime"></i><i id="star" class="a-icon-star-small"></i>
</div>
</body></html>'''
for factor in ['1.000','0.684','0.420']:
 css=js.split('var css=`',1)[1].split('`;',1)[0].replace('__FACTOR__',factor)
 m=cssselect2.Matcher()
 for rule in tinycss2.parse_stylesheet(css,skip_comments=True,skip_whitespace=True):
  if rule.type!='qualified-rule':continue
  for sel in cssselect2.compile_selector_list(tinycss2.serialize(rule.prelude)):
   ds={d.lower_name:tinycss2.serialize(d.value).strip() for d in tinycss2.parse_declaration_list(rule.content) if d.type=='declaration'}
   m.add_selector(sel,ds)
 nodes={e.etree_element.get('id'):e for e in cssselect2.ElementWrapper.from_html_root(html.fromstring(fixture)).iter_subtree() if e.etree_element.get('id')}
 def paint(id,prop):
  vals=[(spec,order,ds[prop]) for spec,order,pseudo,ds in m.match(nodes[id]) if pseudo is None and prop in ds]
  return max(vals)[2] if vals else None
 for id in ['ax-mbs','ax-mbs-content','sw-mbs','card','iou','multi-bundle-card-grid-view']:
  assert paint(id,'background')=='#000' or paint(id,'background-color')=='#000',id
 assert paint('desc','color')=='#fff'
 assert paint('goal','color')=='#fff'
 assert paint('overlay-divider','background')=='#494d4d' or paint('overlay-divider','border-color')=='#494d4d'
 assert paint('overlay-btn','background')=='#000' and paint('overlay-btn','border')=='1px solid #747a7c'
 assert paint('overlay-btn-text','color')=='#fff'
 assert paint('overlay-chevron','filter')=='brightness(0) invert(1)'
 assert paint('overlay-image','filter')=='brightness('+factor+')'
 assert paint('iou-price','color')=='#fff' and paint('iou-whole','color')=='#fff'
 assert paint('iou-button','background')=='#000' and paint('iou-button','border')=='1px solid #747a7c'
 assert paint('iou-btn-text','color')=='#fff'
 assert paint('iou-link','color') is None and paint('iou-link','-webkit-text-fill-color')=='currentColor'
 assert paint('bundle-divider','background')=='#494d4d' or paint('bundle-divider','border-color')=='#494d4d'
 assert paint('bundle-image','filter')=='brightness('+factor+')'
 assert paint('plus-btn','background')=='#303335' and paint('plus-btn','border')=='2px solid #202324'
 assert paint('plus-icon','filter')=='brightness(0) invert(1)'
 for id in ['prime','star']:
  assert paint(id,'filter') is None and paint(id,'color') is None,id
program='const vm=require("vm"),assert=require("assert");let styles=[];let d={getElementById:id=>styles.find(s=>s.id===id),createElement:()=>({}),head:{appendChild:s=>styles.push(s)}};let c={document:d};vm.createContext(c);let s='+json.dumps(js.replace('__FACTOR__','0.420'))+';vm.runInContext(s,c);vm.runInContext(s,c);assert.equal(styles.length,1);'
subprocess.run(['node'],input=program,text=True,check=True,capture_output=True)
print('PASS: v7.600 add-to-cart sheet, IOU card, bundle divider and complementary plus buttons themed with preserved semantics and artwork-only dimming')

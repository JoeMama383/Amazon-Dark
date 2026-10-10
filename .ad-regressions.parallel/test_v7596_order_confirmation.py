"""Probe-shaped thank-you menu coverage and semantic/media negatives."""
from pathlib import Path
import json,subprocess
import cssselect2,tinycss2
from lxml import html
R=Path(__file__).resolve().parents[1]
js=(R/'src/ADOrderConfirmation7596.js').read_text()
assert ''.join(json.loads(x) for x in (R/'src/ADOrderConfirmation7596.js.inc').read_text().splitlines())==js
source=(R/'src/Tweak.xm').read_text();assert '#include "ADOrderConfirmation7596.js.inc"' in source
assert 'order596 stringByReplacingOccurrencesOfString:@"__FACTOR__" withString:[NSString stringWithFormat:@"%.3f",(gP.whiteTame?ad7593Factor:1.0)]]' in source
fixture='''<html><body><div id="checkoutDisplayPage"><div id="typ-body-container">
<div class="a-cardui-deck" id="deck"><div class="a-cardui" id="card"><h2 id="title">Order placed</h2><i class="a-icon a-icon-alert" id="success"></i><div class="a-box atd-banner" id="atd"><div class="a-box-inner a-alert-container" id="inner"><p class="rich-content-paragraph"><span class="a-color-success"><span class="break-word" id="countdown">Blue countdown</span></span></p><span class="a-button a-button-primary" id="shop"><span class="a-button-inner" id="shop-inner"><a class="a-button-text" id="shop-text">Shop now</a></span></span></div></div>
<div class="a-box" id="shipment"><img id="product-image-fixture"/><a class="a-color-link" id="orders-link">See all orders</a></div>
<div class="a-cardui" id="keep"><a class="_cDEzb_caretHeaderLink_123"><svg><path id="caret"/></svg></a><div class="_cDEzb_sextantSquareImageContainer_123" id="art-plane"><img class="_cDEzb_carousel-image_123" id="art"/></div></div>
<div class="a-cardui" id="live"><video class="vjs-tech" id="video"/><img class="_YXN2L_videoImg_19juB" id="poster"/><img class="asv-mum-btn" id="mute"/><li class="_YXN2L_productV3_1 _YXN2L_featured_1" id="featured"><div class="_YXN2L_productLeftMFO_1"><img id="featured-image"/></div></li></div>
<div class="maple-banner__container maple-banner--border" id="credit"><div class="maple-banner__text" id="credit-copy"><strong id="offer">Offer</strong><span class="a-color-link" id="learn"><ins>Learn more</ins></span></div><div class="maple-banner__image"><img id="credit-image"/></div></div>
<div id="ape_thankyou_atf_mshop_wrapper"><div id="ape_thankyou_atf_mshop_placement"><img class="ad-background-image" id="ad-image"/></div><span id="ad-feedback-text-fixture">Sponsored</span><b id="ad-feedback-sprite-fixture"/></div>
<div class="a-carousel-container" id="carousel"><div class="aok-dm-img-container-bg" id="product-floor"><img class="p13n-product-image" id="product"/></div><span class="a-price a-color-price" id="red-price"><span class="a-price-whole" id="red-price-child">10</span></span><i class="a-icon a-icon-star-small" id="stars"/><i class="a-icon a-icon-prime" id="prime"/><span class="a-color-price" id="discount">-5%</span><span class="a-button a-button-primary" id="atc"><span class="a-button-inner"><span class="a-button-text" id="atc-text">Add to cart</span></span></span></div>
<div class="a-cardui" id="continue-floor"><span class="a-button a-button-primary" id="continue">Continue shopping</span></div><hr id="divider"/></div></div>
</div></div><div id="unrelated" class="a-cardui"><span class="a-button a-button-primary" id="unrelated-button"/><img class="p13n-product-image" id="unrelated-img"/></div></body></html>'''
for factor in ['1.000','0.900','0.684','0.420']:
 css=js.split('var css=`',1)[1].split('`;',1)[0].replace('__FACTOR__',factor);m=cssselect2.Matcher()
 for rule in tinycss2.parse_stylesheet(css,skip_comments=True,skip_whitespace=True):
  if rule.type!='qualified-rule':continue
  sels=cssselect2.compile_selector_list(tinycss2.serialize(rule.prelude))
  ds={d.lower_name:tinycss2.serialize(d.value).strip() for d in tinycss2.parse_declaration_list(rule.content) if d.type=='declaration'}
  for sel in sels:m.add_selector(sel,ds)
 nodes={e.etree_element.get('id'):e for e in cssselect2.ElementWrapper.from_html_root(html.fromstring(fixture)).iter_subtree() if e.etree_element.get('id')}
 def paint(id,prop):
  found=[(spec,order,ds[prop]) for spec,order,ps,ds in m.match(nodes[id]) if ps is None and prop in ds];return max(found)[2] if found else None
 for id in ['deck','card','atd','inner','shipment','keep','art-plane','live','featured','credit','carousel','product-floor','continue-floor']:assert paint(id,'background-color')=='#000',id
 for id in ['shop','atc','continue']:assert paint(id,'background')=='#000' and paint(id,'border')=='1px solid #747a7c',id
 for id in ['shop-text','atc-text','title','credit-copy','offer']:assert paint(id,'color')=='#fff',id
 for id in ['countdown','orders-link','stars','prime','discount','learn','success','red-price','red-price-child']:assert paint(id,'color') is None,id
 assert paint('featured','border-color') is None
 assert paint('divider','border-color')=='#494d4d';assert paint('caret','fill')=='#fff'
 for id in ['product-image-fixture','art','video','poster','featured-image','credit-image','ad-image','product']:assert paint(id,'filter')=='brightness('+factor+')',id
 for id in ['card','featured','credit','carousel','stars','prime','success']:assert paint(id,'filter') is None,id
 for id in ['unrelated','unrelated-button','unrelated-img']:assert not m.match(nodes[id]),id
 program='const vm=require("vm"),assert=require("assert");let styles=[];let d={getElementById:id=>styles.find(s=>s.id===id),createElement:()=>({}),head:{appendChild:s=>styles.push(s)}};let c={document:d};vm.createContext(c);let s='+json.dumps(js.replace('__FACTOR__',factor))+';vm.runInContext(s,c);vm.runInContext(s,c);assert.equal(styles.length,1);'
 subprocess.run(['node'],input=program,text=True,check=True,capture_output=True)
print('PASS: thank-you floors/buttons/neutral copy, semantic colors, featured border, gray dividers and artwork-only dimming at disabled/0/45/100; unrelated menus untouched')

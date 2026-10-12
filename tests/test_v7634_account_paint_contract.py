"""Selector/cascade checks for actual captured owners, plus negative controls.
These are structural fixtures, not a substitute for on-device visual validation.
"""
from pathlib import Path
import json,re
import tinycss2,cssselect2
from lxml import etree
R=Path(__file__).resolve().parents[1]
j=(R/'src/ADAccountMenus7634.js').read_text()
css=(R/'src/ADAccountMenus7634.css').read_text()+j.split('if(__TAME__)s.textContent+=`',1)[1].split('`;',1)[0].replace('__FACTOR__','0.42')
def matcher(css):
 m=cssselect2.Matcher()
 for rule in tinycss2.parse_stylesheet(css,skip_comments=True,skip_whitespace=True):
  assert rule.type=='qualified-rule',rule
  declarations=tinycss2.parse_declaration_list(rule.content,skip_comments=True,skip_whitespace=True)
  for d in declarations:
   assert d.type=='declaration'
   assert d.lower_name not in {'display','visibility','opacity','width','height','padding','margin','position','transform','border-radius','border-width'},d.lower_name
  for sel in cssselect2.compile_selector_list(rule.prelude):m.add_selector(sel,declarations)
 return m
M=matcher(css)
def paint(html,matcher=M):
 root=etree.fromstring(html);out={}
 for e in cssselect2.ElementWrapper.from_html_root(root).iter_subtree():
  if e.etree_element.get('data-check') is None:continue
  for _,_,pseudo,ds in matcher.match(e):
   if pseudo:continue
   for d in ds:out[d.lower_name]=tinycss2.serialize(d.value).strip()
 return out
cases=[
 ('order transaction','<div id="a-page"><div class="od-modernized"><div data-testid="viewTransactionsLink-content-wrapper-outline" data-check=""/></div></div>','background','#000'),
 ('order delivery','<div id="a-page"><div class="od-modernized"><div class="udm-primary-delivery-message"><span data-check=""/></div></div></div>','color','#fff'),
 ('Angular settings','<div id="ng-app" class="desktopMargin_myx"><div class="myx-box" data-check=""/></div>','background-color','#000'),
 ('Angular dropdown','<div id="ng-app"><a class="myx-button" data-check=""/></div>','background','#000'),
 ('Devices tooltip','<div id="root"><div class="NavigationBar-module__navHeader_myx_123"/><div class="tooltip" data-check=""/></div>','background-color','#000'),
 ('Device image','<div id="root"><div class="NavigationBar-module__navHeader_myx_123"/><div class="device-details-image"><img data-check=""/></div></div>','filter','brightness(0.42)'),
 ('Content dialog','<div id="root"><div class="NavigationBar-module__navHeader_myx_123"/><div class="DialogSheet-module_dialog-sheet-container_123" data-check=""/></div>','background-color','#000'),
 ('Privacy card','<div id="root"><div class="NavigationBar-module__navHeader_myx_123"/><div class="Card-module_card_mobile_123" data-check=""/></div>','background-color','#000'),
 ('Books FTUE button','<div id="customer-corner-root"><button data-testid="followsSeeItMoreButton" data-check=""/></div>','background','#000'),
 ('Books genres','<div id="customer-corner-root"><div id="view-nav-tabs"><div role="tab" data-check=""/></div></div>','color','#fff'),
 ('Alexa voice','<div id="apd-content-wrapper"><div class="utterance-title" data-check=""/></div>','color','#fff'),
 ('Alexa sound/date filter','<div id="apd-content-wrapper"><div class="filter-row" data-check=""/></div>','border-color','#494d4d'),
 ('Alexa device history','<div id="apd-content-wrapper"><div class="dsh-history-content-device-state"><div data-check=""/></div></div>','color','#fff'),
 ('Alexa activity input','<div id="apd-content-wrapper"><input type="date" data-check=""/></div>','background','#17191a'),
 ('Alexa permission','<div id="apd-content-wrapper"><div class="scope-name" data-check=""/></div>','color','#fff'),
 ('Alexa data description','<div id="apd-content-wrapper"><div class="myad-sub-section-description"><div data-check=""/></div></div>','color','#fff'),
 ('Detached retention sheet','<div class="apd-modal-box wide-modal" data-check=""/>','background-color','#000'),
 ('Help FAQ','<div class="cs-help-v4"><h2 data-check=""/></div>','color','#fff'),
 ('Help picker artwork','<div class="cs-help-v4"><img id="picker-img" data-check=""/></div>','filter','brightness(0.42)'),
 ('Buy Again photos','<div data-csa-c-painter="buy-again-grid-mobile-cards"><img class="_YnV5L_imgLimit_123" data-check=""/></div>','filter','brightness(0.42)'),
 ('Buy Again progress','<div data-csa-c-painter="cart-progress-indicator-cards"><div class="a-meter" data-check=""/></div>','background-color','#494d4d'),
]
for name,html,prop,value in cases:assert paint(html).get(prop)==value,(name,paint(html))
# Authored links, selected outlines, thumbs, and unrelated pages must survive.
for html in [
 '<div id="apd-content-wrapper"><span class="selected-filter" data-check=""/></div>',
 '<div id="apd-content-wrapper"><div class="menu-options-list"><a class="menu-row active" data-check=""/></div></div>',
 '<div class="cs-help-v4"><p><a data-check=""/></p></div>',
 '<div id="ng-app" class="desktopMargin_myx"><div class="myx-color-state" data-check=""/></div>',
 '<div id="unrelated"><button data-check=""/></div>',
]:assert 'color' not in paint(html),paint(html)
assert 'background-color' not in paint('<div id="apd-content-wrapper"><div class="toggleSwitch on"><label><div class="slider" data-check=""/></label></div></div>')
assert 'border-color' not in paint('<div id="root"><div class="NavigationBar-module__navHeader_myx_123"/><div role="button" class="mobile-filter-layout-item-selected" data-check=""/></div>')
print('PASS: 21 captured paint-owner fixtures; semantic/selection/thumb/unrelated negative controls; no geometry or visibility mutations')
shadow=j.split('var shadowCSS=`',1)[1].split('`+',1)[0]+'.coverImage{filter:brightness(0.42)!important;}'
shadow=re.sub(r':host\(([^)]+)\)',lambda m:'[data-host="'+m[1]+'"]',shadow).replace(':host','[data-host]')
S=matcher(shadow)
assert paint('<div data-host="bds-book-cover-image"><img class="coverImage" data-check=""/></div>',S)['filter']=='brightness(0.42)'
for cls in ['fullStar','halfStar']:
 assert 'filter' not in paint('<div data-host="bds-star-rating"><img class="'+cls+'" data-check=""/></div>',S)
selected=paint('<div data-host="bds-tabs"><button class="tab large selected" data-check=""/></div>',S)
assert 'border-color' not in selected and 'color' not in selected,selected
assert paint('<div data-host="bds-button"><button><span><img data-check=""/></span></button></div>',S)['filter']=='brightness(0) invert(1)'
print('PASS: shadow cover/glyph paint, original star artwork and selected blue tab color/border retained')

"""v7.621 order-recommendation and change-shipping sheet owner/cascade contracts.
The selectors use identifiers extracted from distinct v7.620 VIEWPORT r1/r2.
No personal address data or other captured private text is embedded here.
"""
import json
import subprocess
from pathlib import Path
import tinycss2
import cssselect2
from lxml import html

root=Path(__file__).resolve().parents[1]
src=(root/'src/ADOrdersRecommendationsShipping7621.js').read_text()
inc=(root/'src/ADOrdersRecommendationsShipping7621.js.inc').read_text()
tweak=(root/'src/Tweak.xm').read_text()
assert src==''.join(json.loads(line) for line in inc.splitlines() if line.strip()), 'generated include disagrees with JS'
assert tweak.count('#include "ADOrdersRecommendationsShipping7621.js.inc"')==1
assert tweak.count('base=[base stringByAppendingString:ordersShipping7621];')==1
assert 'Version: 7.621~orders-recommendations-shipping-oled' in (root/'layout/DEBIAN/control').read_text()
assert '#define AD_VERSION "v7.621-orders-recommendations-shipping-oled"' in tweak
css=src.split('s.textContent=`',1)[1].split('`;',1)[0]
rules=tinycss2.parse_rule_list(css,skip_comments=True,skip_whitespace=True)
assert not [r for r in rules if r.type=='error'], 'CSS syntax invalid'
matcher=cssselect2.Matcher()
for rule in rules:
    if rule.type!='qualified-rule':
        continue
    decls=tinycss2.parse_declaration_list(rule.content,skip_comments=True,skip_whitespace=True)
    assert not [x for x in decls if x.type=='error']
    payload={x.lower_name: tinycss2.serialize(x.value).strip() for x in decls if x.type=='declaration' and x.important}
    for selector in cssselect2.compile_selector_list(tinycss2.serialize(rule.prelude)):
        matcher.add_selector(selector,payload)

def paint(markup, selector):
    doc=html.fromstring(markup)
    sel=cssselect2.compile_selector_list(selector)
    for node in cssselect2.ElementWrapper.from_html_root(doc).iter_subtree():
        if any(s.test(node) for s in sel):
            result={}
            for match in matcher.match(node):
                result.update(match[-1])
            return result
    raise AssertionError('No element '+selector)

orders='''<html><body><div id="a-page"><div class="od-modernized"><div class="od-container"><div id="mobile-yo-orderdetails_recommendations-widget-container_mobile-yo-orderdetails_0_container"><div class="p13n-sc-mobile-section"><div class="a-carousel-container p13n-sc-shoveler"><div class="a-carousel-viewport"><ol class="a-carousel"><li class="a-carousel-card"><div class="p13n-uf"><div class="p13n-sc-uncoverable-faceout"><img class="p13n-product-image"/><a class="a-link-normal"><span>PRODUCT</span></a><i class="a-icon a-icon-star-small"></i><span class="a-price"><span class="a-price-symbol">$</span><span class="a-price-whole">99</span><span class="a-price-fraction">99</span></span><span class="a-size-mini a-color-base">FREE <b>tomorrow</b></span><i class="a-icon-prime"></i></div></div></li></ol></div></div></div></div></div></div></body></html>'''
for q in ['.a-carousel-container','.a-carousel-viewport','.a-carousel-card','.p13n-sc-uncoverable-faceout']:
    assert paint(orders,q).get('background-color')=='#000',q
for q in ['.a-price','.a-price-symbol','.a-price-whole','.a-price-fraction','.a-size-mini.a-color-base','.a-size-mini b']:
    assert paint(orders,q).get('color')=='#fff',q
for q in ['.a-link-normal','.p13n-product-image','.a-icon-prime','.a-icon-star-small']:
    assert not paint(orders,q), 'Authored dynamic media/color modified: '+q

ship='''<html><body><div class="a-sheet-web-container"><div class="a-sheet-web"><div class="a-sheet-heading-container"><h1 class="a-sheet-heading">Change shipping address</h1></div><div class="a-sheet-content-container"><div id="changeShippingAddressPreloadContent"><div id="change-shipping-address-bottom-sheet-container"><div id="address-selection-bottom-sheet"><span>Choose address</span><div id="address-options-scroller"><ul id="address-options-list"><li><span class="a-button a-button-toggle shipping-address-option-bottom-sheet a-button-selected"><span class="a-button-inner"><span class="a-button-text">SELECTED</span></span></span></li><li><span class="a-button shipping-address-option-bottom-sheet"><span class="a-button-inner"><span class="a-button-text">UNSELECTED</span></span></span></li><li><span id="manage-address-book-button" class="a-button shipping-address-option-bottom-sheet"><span class="a-button-inner"><span class="a-button-text"><a id="manage-address-book-link" class="a-link-normal">MANAGE</a></span></span></span></li></ul></div><div id="change-shipping-address-bottom-sheet-buttons"><span id="ship-to-address-button" class="a-button a-button-disabled"><span class="a-button-inner"><button class="a-button-text">Ship to this address</button></span></span></div></div></div></div></div></div></body></html>'''
for q in ['.a-sheet-web','.a-sheet-content-container','.a-sheet-heading-container','#changeShippingAddressPreloadContent',
          '.shipping-address-option-bottom-sheet.a-button-selected','.shipping-address-option-bottom-sheet:not(.a-button-selected)',
          '#manage-address-book-button','#ship-to-address-button']:
    props=paint(ship,q)
    assert props.get('background-color')=='#000' or props.get('background')=='#000', (q,props)
for q in ['.a-sheet-heading','.shipping-address-option-bottom-sheet .a-button-text']:
    assert paint(ship,q).get('color')=='#fff',q
assert 'border-color' not in paint(ship,'.a-button-selected'), 'blue selected border overridden'
assert paint(ship,'.shipping-address-option-bottom-sheet:not(.a-button-selected)')['border-color']=='#747a7c'
assert paint(ship,'#ship-to-address-button')['border-color']=='#747a7c'
assert paint(ship,'#ship-to-address-button .a-button-text')['color']=='#b7baba'
assert paint(ship,'#manage-address-book-link').get('-webkit-text-fill-color')=='currentColor'

unrelated='''<html><body><div id="gwm-Deck"><div class="a-carousel-container p13n-sc-shoveler"><span class="a-price">OTHER</span></div><div class="a-sheet-web"><h1 class="a-sheet-heading">Unrelated</h1></div></div></body></html>'''
for q in ['.a-carousel-container','.a-price','.a-sheet-web','.a-sheet-heading']:
    assert not paint(unrelated,q), 'wrong menu affected: '+q

for forbidden in ['MutationObserver','setInterval(','requestAnimationFrame(','object-fit:','background-size:','filter:','opacity:','display:block','height:','width:','border-width:','border-radius:']:
    assert forbidden not in css, forbidden
subprocess.run(['node','--check',str(root/'src/ADOrdersRecommendationsShipping7621.js')],check=True)
print('PASS v7.621: probe-matched Orders rail and shipping sheet OLED; authored blue/Prime/images/geometry untouched')

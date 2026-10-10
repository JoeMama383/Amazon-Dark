"""v7.595 probe-backed Web owners and independent VIEWPORT contract."""
import json
from pathlib import Path
import tinycss2
import cssselect2
from lxml import html
r=Path(__file__).resolve().parents[1]
t=(r/'src/Tweak.xm').read_text()
u=(r/'src/ADUniversalUIProbe7362.inc').read_text()
im=''.join(json.loads(x) for x in (r/'src/ADUIImmediate7568.js.inc').read_text().splitlines())
j=''.join(json.loads(x) for x in (r/'src/ADMenuFollowup7595.js.inc').read_text().splitlines())
assert '#include "ADMenuFollowup7595.js.inc"' in t
assert 'stringByAppendingString:menu595' in t
assert 'gP.whiteTame?@"true":@"false"' in t
assert 'MutationObserver' not in j and 'setInterval(' not in j
css=j.split('var css=`',1)[1].split('`;',1)[0]+'\n'+j.split('css+=`',1)[1].split('`;',1)[0].replace('__AD7595_FACTOR__','0.420')
matcher=cssselect2.Matcher();nrules=0
for rule in tinycss2.parse_stylesheet(css,skip_comments=True,skip_whitespace=True):
    assert rule.type=='qualified-rule',rule
    n=nrules;nrules+=1
    ds={d.lower_name:tinycss2.serialize(d.value).strip() for d in tinycss2.parse_declaration_list(rule.content) if d.type=='declaration'}
    for sel in cssselect2.compile_selector_list(tinycss2.serialize(rule.prelude)):
        matcher.add_selector(sel,ds)
assert nrules>=28

def props(document,id):
    root=cssselect2.ElementWrapper.from_html_root(html.fromstring(document))
    w=next(e for e in root.iter_subtree() if e.etree_element.get('id')==id)
    winning={}
    for spec,idx,pseudo,ds in matcher.match(w):
        if pseudo is None:winning.update(ds)
    return winning
BUY='<html><body><div id="ee-aisles-on-ba-widget-container"><div class="_everyday-essentials-aisles_style_eeAislesContainer__1H_pb" id="discover"></div></div><div id="ordersSearch"></div><div class="_YnV5L_rootBackground_2Te_-" id="buy-shell"><div class="_YnV5L_asinInfo_U9mvu" id="card"><a class="_YnV5L_linkTitle_2NVDs _YnV5L_makeTextBlack_2OWCd" id="title">Item</a><img class="_YnV5L_imgLimit_1SzV8" id="image"><div class="_YnV5L_addToCartContainer_3vQL-" id="button-wrap"><span class="a-button a-button-primary" id="cart-button"><span class="a-button-inner" id="cart-inner"><span class="a-button-text" id="cart-label">Add to Cart</span></span></span></div></div></div></body></html>'
assert props(BUY,'discover')['background']=='#000'
assert props(BUY,'buy-shell')['background']=='#000'
assert props(BUY,'title')['color']=='#e8e6e3'
assert props(BUY,'image')['filter']=='brightness(0.420)'
assert props(BUY,'cart-button')['border']=='1px solid #747a7c'
assert props(BUY,'cart-inner')['border']=='0'
assert props(BUY,'cart-label')['color']=='#fff'
PDP='<html><body><div id="dp"><div class="aplus-premium"><div id="comparison-table-container-6"><table><tr><td class="aplus-data-column description" id="td"><span id="metric">Specs</span></td><th id="th">Image</th></tr></table><span class="a-button-primary" id="buy"><span class="a-button-inner" id="inner"><span class="a-button-text" id="ctext">Add to Cart</span></span></span><a class="a-link-normal" id="link">F50</a></div></div></div></body></html>'
assert props(PDP,'td')['background']=='#000'
assert props(PDP,'th')['border-color']=='#494d4d'
assert props(PDP,'metric')['color']=='#e8e6e3'
assert props(PDP,'buy')['border']=='1px solid #747a7c'
assert props(PDP,'inner')['border']=='0'
assert props(PDP,'link')['-webkit-text-fill-color']=='currentColor'
assert 'FULL_WEB_FIRST' in u and 'ADUIDetectPDPSession7451(webs' in u
assert 'ADUINativeSnapshotAsync7449(nil,NO,30000,28000,@"post-web-full"' in u
assert 'ADUIImmediateEvidence7568(YES,@"armed-background-during-full")' in u
assert 'scope=visible-viewport-only fullTraversal=0' in u
assert 'complete?@"completed":@"partial"' in u
assert 'childFrameCoverage' in u
assert 'var q=[document.documentElement],qi=0' not in im
assert 'sampledPoints' in im and 'frameCount' in im and 'elementsFromPoint' in im
assert 'truncated:qi<q.length' not in im
print('PASS: v7.595 CSS and genuine probe owner/viewport contracts')

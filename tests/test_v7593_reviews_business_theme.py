"""Real selector matching for review histogram / controls and safe business-page isolation."""
from pathlib import Path
import json
import tinycss2
import cssselect2
from lxml import html

ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
J=''.join(json.loads(l) for l in (ROOT/'src/ADReviewBusiness7593.js.inc').read_text().splitlines())
assert 'reviewBusiness=[NSString stringWithUTF8String:' in S
assert 'stringByAppendingString:reviewBusiness' in S
assert '%.3f' in S and 'gP.whiteTame' in S
assert "if(!d.body||d.querySelector('#dp,#checkoutDisplayPage,#sc-page-container'))return" in J
assert "data-ad7593-business-card" in J
assert 'MutationObserver' not in J and 'setInterval(' not in J and 'setTimeout(' not in J
CSS=J.split('var css=`',1)[1].split('`;',1)[0]+'\n'+J.split('css+=`',1)[1].split('`;',1)[0].replace('__AD7593_FACTOR__','0.710')
M=cssselect2.Matcher()
for rule in tinycss2.parse_stylesheet(CSS,skip_whitespace=True,skip_comments=True):
    assert rule.type=='qualified-rule',rule
    decl={d.lower_name:(tinycss2.serialize(d.value).strip(),d.important)
          for d in tinycss2.parse_declaration_list(rule.content) if d.type=='declaration'}
    for sel in cssselect2.compile_selector_list(tinycss2.serialize(rule.prelude)):
        M.add_selector(sel,decl)

DOC=html.fromstring('''<html><body>
 <div id="mobile-product-reviews">
  <h2 id="rev-heading">Customer reviews</h2>
  <ul id="histogramTable"><li><a class="a-link-normal histogram-row-container" id="ratinglink"><div class="a-meter" id="meter"><div class="a-meter-bar" id="orange"></div></div></a></li></ul>
  <span class="writeReviewButton" id="write"><span class="a-button-inner"><a><span class="a-button-text" id="write-label">Write a review</span></a></span></span>
  <img id="review-photo" class="review-image" />
  <span class="a-color-secondary" id="secondary">ratings</span>
 </div>
 </body></html>''')
WRAP=cssselect2.ElementWrapper.from_html_root(DOC)
NODE={w.etree_element.get('id'):w for w in WRAP.iter_subtree() if w.etree_element.get('id')}
def prop(id,key):
    wins=[]
    for spec,order,pseudo,decl in M.match(NODE[id]):
        if pseudo is None and key in decl:
            v,important=decl[key]
            wins.append(((important,spec,order),v))
    return max(wins)[1] if wins else None
assert prop('rev-heading','color')=='#fff'
assert prop('meter','background')=='#303335'
assert prop('orange','background')=='#ff6200'
assert prop('write','background')=='#000'
assert prop('write','border')=='1px solid #747a7c'
assert prop('write-label','color')=='#fff'
assert prop('review-photo','filter')=='brightness(0.710)'
assert prop('secondary','color')=='#b1b5b5'
assert prop('ratinglink','-webkit-text-fill-color')=='currentColor'
BUS=html.fromstring('''<html data-ad7593-business-card="1"><body><main><h1 id="name">Prime Business Card</h1><button id="apply"><span id="label">Apply now</span></button><a id="link">Fees</a><img id="artwork"></main></body></html>''')
WRAP=cssselect2.ElementWrapper.from_html_root(BUS)
NODE={w.etree_element.get('id'):w for w in WRAP.iter_subtree() if w.etree_element.get('id')}
assert prop('name','color')=='#fff'
assert prop('apply','background')=='#000'
assert prop('apply','border')=='1px solid #747a7c'
assert prop('label','color')=='#fff'
assert prop('link','-webkit-text-fill-color')=='currentColor'
assert prop('artwork','filter')=='brightness(0.710)'
print('PASS: v7.593 reviews semantic histogram/CTA/images and standalone guarded Prime Business Card colors')

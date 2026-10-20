"""Review ownership reacts to DOM structure without a JS classifier."""
import json
from pathlib import Path
import subprocess
from lxml import etree
import cssselect2

root = Path(__file__).resolve().parents[1]
helper = (root / 'src/ADRenderScope7640.js').read_text()
assert 'MutationObserver' not in helper
assert 'data-ad7642-reviews' not in helper
js = r'''
const vm=require('vm'),assert=require('assert');
const c={location:{pathname:'/s'}};c.window=c;c.top=c;
vm.createContext(c);vm.runInContext(SOURCE,c);
const css=':is(body:has(#mobile-product-reviews),body:has(#cruise-customer-reviews)) .writeReviewButton{color:white}';
for(const path of ['/s','/dp/X','/','/live','/medical','/product-reviews/X']){
 c.location.pathname=path;
 const s={id:'ad7593-review-business',tagName:'STYLE',textContent:''};
 c.ad7640Style(s).textContent=css;
 assert.equal(s.textContent,css);
}
console.log('PASS: review CSS retained without observer, body marker or classifier');
'''.replace('SOURCE', json.dumps(helper))
subprocess.run(['node'], input=js, text=True, check=True)
selector = ':is(body:has(#mobile-product-reviews),body:has(#cruise-customer-reviews)) .writeReviewButton'
compiled = cssselect2.compile_selector_list(selector)[0]
def matches(body):
    return any(compiled.test(node) for node in cssselect2.ElementWrapper.from_html_root(body).iter_subtree())
body = etree.fromstring('<body><button class="writeReviewButton"/></body>')
assert not matches(body)
owner = etree.SubElement(body, 'div', id='mobile-product-reviews')
assert matches(body)
owner.set('id','cruise-customer-reviews'); assert matches(body)
owner.set('id','ordinary'); assert not matches(body)
owner.set('id','mobile-product-reviews'); body.remove(owner); assert not matches(body)
assert matches(etree.fromstring('<body><div id="cruise-customer-reviews"/><button class="writeReviewButton"/></body>'))
print('PASS: static review ownership follows insertion, removal, IDs and body replacement')

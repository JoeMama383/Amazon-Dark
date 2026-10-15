"""Protect hot-route controls while omitting full-page-only theme payloads."""
from pathlib import Path
import json
import subprocess

root=Path(__file__).resolve().parents[1]
helper=(root/'src/ADRenderScope7640.js').read_text()
assert ''.join(json.loads(line) for line in (root/'src/ADRenderScope7640.js.inc').read_text().splitlines())==helper
js=r'''
const vm=require('vm'),assert=require('assert');
function context(path,child=false){
 const c={location:{pathname:path}};c.window=c;c.top=child?{}:c;
 vm.createContext(c);vm.runInContext(SOURCE,c);return c;
}
const shared=[
 '#ax-mbs .a-button{background:black}',
 '#reviews-filter-options-view button{color:white}',
 '#a-page:has(#ssf-share-sheet) .share-link{color:cyan}',
 'body:is(*,#ordersSearch) .shared-control{border-color:gray}',
 '#a-popover-content-1 .a-button{background:black}',
 '#sc-page-container-preview{color:orange}',
 '#customer-corner-root-embedded .label{color:white}',
 '#live-page-container-mobile h2,#ax-mbs .headline{color:white}',
 ':is(#typ-body-container,#dp) .a-price{color:white}',
 '#list-create-form input{color:white}',
 '#GLUXZipUpdateInput{color:white}',
 '#store-locator-map canvas{filter:brightness(.684)}'
].join('\n');
const dedicated='#typ-body-container .a-box{background:black}'+
 '#live-page-container-mobile .a-section{color:white}'+
 'body:has(#ordersSearch) #ordersSearch{background:black}';
const sheetIDs=['ad7480-returns-theme','ad7412-address-management',
 'ad7596-order-confirmation','ad7597-live-and-thankyou'];
for(const path of ['/s','/s/ref=nb','/dp/X','/gp/product/X','/gp/aw/d/X']){
 const c=context(path);
 assert.equal(c.ad7640ScopeCSS(dedicated+shared),shared);
 for(const id of sheetIDs){
  const style={tagName:'STYLE',id,textContent:''};
  c.ad7640Style(style).textContent='@media screen{'+dedicated+'}';
  assert.equal(style.textContent,'');
 }
 const style={tagName:'STYLE',id:'ad7600-pdp-followup',textContent:''};
 c.ad7640Style(style).textContent=shared;assert.equal(style.textContent,shared);
}
// Child frames and complete non-hot menus keep authored source, even at-rules.
for(const [path,child] of [['/',false],['/live',false],['/gp/cart/view.html',false],
 ['/gp/buy/thankyou/handlers/display.html',false],['/gp/css/returns/homepage.html',false],
 ['/gp/css/order-history',false],['/gp/your-account/your-addresses',false],
 ['/medical',false],['/s',true],['/dp/X',true]]){
 const c=context(path,child),css=dedicated+shared;
 assert.equal(c.ad7640ScopeCSS(css),css);
 for(const id of sheetIDs){
  const style={tagName:'STYLE',id,textContent:''};
  c.ad7640Style(style).textContent=css;assert.equal(style.textContent,css);
 }
}
console.log('PASS: shared overlays, mixed selectors and owner-prefix negatives retain CSS; full-page sheets remain on their own routes and child frames');
'''.replace('SOURCE',json.dumps(helper))
subprocess.run(['node'],input=js,text=True,check=True)

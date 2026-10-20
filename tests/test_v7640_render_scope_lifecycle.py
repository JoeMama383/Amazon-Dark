"""Run source filtering and detached-head recovery, including negative cases."""
from pathlib import Path
import json, subprocess
r=Path(__file__).resolve().parents[1]
helper=(r/'src/ADRenderScope7640.js').read_text()
assert ''.join(json.loads(x) for x in (r/'src/ADRenderScope7640.js.inc').read_text().splitlines())==helper
t=(r/'src/Tweak.xm').read_text()
for text in ['ad7640Style(s).textContent','NSRegularExpressionSearch','if(!ad7640HotRoute()&&start>=0',
             '(slot==0?@".appendChild(ad7640RetainStyle(s))":@".appendChild(ad7644AppendStyle(s))")',
             'withString:@".appendChild(ad7644AppendStyle(style))"', '#include "ADRenderScope7640.js.inc"']:
    assert text in t,text
for forbidden in ['getComputedStyle','offsetHeight','querySelector','setTimeout','setInterval']:
    assert forbidden not in helper,forbidden
# v7.644 restores declarative review ownership. No theme observer remains.
assert 'MutationObserver' not in helper
test=r'''
const vm=require('vm'),assert=require('assert');
function context(path,child=false){
 const events={},nodes=[];
 const d={head:{appendChild(n){nodes.push(n);n.isConnected=true}},
 getElementById(id){return nodes.find(n=>n.id===id&&n.isConnected)||null},
 addEventListener(n,f){events[n]=f}};
 const c={document:d,location:{pathname:path},WeakSet};c.window=c;c.top=child?{}:c;
 c.addEventListener=(n,f)=>events[n]=f;vm.createContext(c);vm.runInContext(SOURCE,c);
 return {c,d,events,nodes};
}
const home='#gwm-Deck-btf .text{color:white!important}',
 interests='#a-page:has(#interests-ai-sticky-div):has(#product-grid) span{color:white}',
 product='#dp .text{color:white!important}',
 mixed='#gwm-Deck-btf .text,#dp .text{color:gray}',
 near='#gwm-Deck-btf-other .text{color:orange}',
 at='@media (max-width:600px){'+home+product+'}',
 data='#dp img{background:url("data:image/svg+xml,<svg>{}</svg>")}',
 comment='/* { comma, } */',
 css=comment+home+interests+product+mixed+near+at+data;
for(const route of ['/dp/ASIN','/gp/product/ASIN','/gp/aw/d/ASIN']){
 const {c}=context(route);const out=c.ad7640ScopeCSS(css);
 assert.equal(out,product+mixed+near+at+data);
 assert.equal(c.ad7640ScopeCSS('#dp {color:"unfinished'), '#dp {color:"unfinished');
 assert.equal(c.ad7640ScopeCSS(home+'broken{'),home+'broken{');
}
for(const route of ['/','/interests','/saves','/dp-other','/gp/your-account'])
 assert.equal(context(route).c.ad7640ScopeCSS(css),css);
assert.equal(context('/s',true).c.ad7640ScopeCSS(css),css);
const search=context('/s').c;
assert.equal(search.ad7640ScopeCSS(product+mixed+near+at),near+at);
const shared='#search .text,#dp .text{color:white}';
assert.equal(search.ad7640ScopeCSS(shared),shared);
const universal='body:is(*,#dp) .shared{color:white}';
assert.equal(search.ad7640ScopeCSS(universal),universal);
assert.equal(search.ad7640ScopeCSS('body:is(*,#dp) #dp .text{color:white}'),'');
assert.equal(context('/dp/X').c.ad7640ScopeCSS('#search span{color:red}'+product),product);
const styled={tagName:'STYLE',id:'ad7-test',textContent:''};
search.ad7640Style(styled).textContent=product+shared;
search.ad7640Style(styled).textContent+=near;
assert.equal(styled.textContent,shared+near);
const appStyle={tagName:'STYLE',id:'app-css'};
assert.equal(search.ad7640Style(appStyle),appStyle);
const {c,d,events,nodes}=context('/');
const a={tagName:'STYLE',id:'ad7-menu-theme',isConnected:false},
 b={tagName:'STYLE',id:'ad7482-new-menus',isConnected:false};
assert.equal(c.ad7640RetainStyle(a),a);c.ad7640RetainStyle(a);c.ad7640RetainStyle(b);
c.ad7640RetainStyle({tagName:'STYLE',id:'amazon-owned'});
assert.equal(c.__ad7640Styles.nodes.length,2);
events.DOMContentLoaded();assert.deepEqual(nodes,[a,b]);
events.load();events.pageshow();assert.equal(nodes.length,2);
// Head replacement after the first lifecycle event, before load.
a.isConnected=false;b.isConnected=false;events.load();assert.equal(nodes.length,4);
assert.equal(nodes[2],a);assert.equal(nodes[3],b);
// A newer installed sheet wins over a retained disconnected predecessor.
a.isConnected=false;
const replacement={tagName:'STYLE',id:a.id,isConnected:true};nodes.push(replacement);
events.pageshow();assert.equal(nodes.length,5);
assert.equal(c.__ad7640Styles.nodes[0],replacement);
c.ad7640RetainStyle(replacement);assert.equal(c.__ad7640Styles.nodes.length,2);
replacement.isConnected=false;events.pageshow();assert.equal(nodes[5],replacement);
console.log('PASS: source filtering preserves mixed rules, at-rules, unknown routes and child frames; lifecycle restores only detached owned styles without duplicates');
'''.replace('SOURCE',json.dumps(helper))
subprocess.run(['node'],input=test,text=True,check=True)

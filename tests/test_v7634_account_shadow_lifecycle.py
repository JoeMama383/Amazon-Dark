"""Exercise shipped Books shadow-root lifecycle, including disabled taming."""
from pathlib import Path
import json, subprocess, shutil
R=Path(__file__).resolve().parents[1]
j=(R/'src/ADAccountMenus7634.js').read_text()
assert ''.join(json.loads(s) for s in (R/'src/ADAccountMenus7634.js.inc').read_text().splitlines()) == j
assert json.loads(j.split('s.textContent=',1)[1].split(';\nif(__TAME__)',1)[0]) == (R/'src/ADAccountMenus7634.css').read_text()
assert '#include "ADAccountMenus7634.js.inc"' in (R/'src/Tweak.xm').read_text()
assert not any(x in j for x in ['MutationObserver(', 'setInterval(', 'requestAnimationFrame(', 'getComputedStyle(', 'getBoundingClientRect('])
node=shutil.which('node')
assert node, 'Node required for runtime lifecycle regression'
harness=r'''
const vm=require('vm'), assert=require('assert');
const source=SOURCE;
for(const tame of [false,true])for(const fallback of [false,true]){
 let sheets=[], styles=[], queries=0, calls=0;
 class Sheet {constructor(){if(fallback)throw Error('unsupported');sheets.push(this)}replaceSync(x){this.css=x}}
 class Root {constructor(){this.adoptedStyleSheets=[];this.children=[];this.hosts=[]}appendChild(x){this.children.push(x)}getElementById(id){return this.children.find(x=>x.id===id)}querySelectorAll(){queries++;return this.hosts}}
 class Element {constructor(tag){this.tagName=tag}attachShadow(options){calls++;if(options.fail)throw Error('native error');this.options=options;const r=new Root();if(options.mode!=='closed')this.shadowRoot=r;return r}}
 const native=Element.prototype.attachShadow;
 const oldHost=new Element('BDS-BUTTON');const oldRoot=oldHost.attachShadow({mode:'open'});
 const nested=new Element('BDS-BOOK-PRICE');oldRoot.hosts.push(nested);nested.attachShadow({mode:'open'});
 const owner=new Root();owner.hosts=[oldHost];
 const d={readyState:'complete',getElementById(id){return id==='customer-corner-root'?owner:styles.find(x=>x.id===id)},createElement(tag){return {tagName:tag}},head:{appendChild(x){styles.push(x)}}};
 const context={document:d,Element,CSSStyleSheet:Sheet,Set,Array};context.window=context;
 const code=source.replaceAll('__TAME__',String(tame)).replaceAll('__FACTOR__','0.42');vm.runInNewContext(code,context);
 const hasPaint=r=>fallback?r.children.length===1:r.adoptedStyleSheets.length===1;
 assert(hasPaint(oldRoot)&&hasPaint(nested.shadowRoot),'late existing nested roots painted');
 const unrelated=new Element('UNRELATED-COMPONENT');const unrelatedRoot=unrelated.attachShadow({mode:'open'});assert.equal(unrelatedRoot.adoptedStyleSheets.length,0);assert.equal(unrelatedRoot.children.length,0);
 const host=new Element('BDS-BOOK-COVER-IMAGE');const options={mode:'closed',delegatesFocus:true};const root=host.attachShadow(options);assert(hasPaint(root));assert.equal(host.options,options);assert.equal(host.shadowRoot,undefined);
 assert.throws(()=>host.attachShadow({fail:true}),/native error/);
 const css=fallback?root.children[0].textContent:root.adoptedStyleSheets[0].css;
 assert.equal(css.includes('.coverImage{filter:brightness(0.42)'),tame);
 assert(!css.includes('.fullStar{')&&!css.includes('.halfStar{'));
 const wrapper=Element.prototype.attachShadow,queryCount=queries;vm.runInNewContext(code,context);assert.equal(Element.prototype.attachShadow,wrapper);assert.equal(queries,queryCount);assert.equal(styles.length,1);
 assert.equal(styles[0].textContent.includes('filter:brightness(0.42)'),tame);
 if(!fallback)assert.equal(root.adoptedStyleSheets[0],oldRoot.adoptedStyleSheets[0]);
}
console.log('PASS: nested/existing/open/closed roots, unrelated passthrough, exceptions, shared styles, fallback, TWB off, reinjection');
'''.replace('SOURCE',json.dumps(j))
subprocess.run([node,'-e',harness],check=True)

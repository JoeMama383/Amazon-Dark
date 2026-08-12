#!/usr/bin/env python3
"""Exercise the locked v5.434 Cart and v5.435 Shopping Compare contracts."""
from pathlib import Path
import importlib.util
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "src/Tweak.xm"
NODE = shutil.which("node")

if not NODE:
    print("checkbox-stock-435 fixture: SKIP (node not installed)")
    raise SystemExit(0)

spec = importlib.util.spec_from_file_location("lint_js", ROOT / "scripts/lint-js.py")
lint_js = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lint_js)
source = SOURCE.read_text(encoding="utf-8")
fixes = lint_js.literals_in(lint_js.function_body(source, "ADFixesLiteral")).replace("%%", "%")
css_start = fixes.index("{css:'") + len("{css:'")
css_end = fixes.index("',invert:", css_start)
fixes_css = fixes[css_start:css_end]
retired_shopping_selectors = [
    "[class*=copilot-compare][class*=on-image-button]",
    "[class*=copilot-compare] [class*=on-image-button]",
    "[class*=s-product-image] button[aria-label*=ompare]",
    "[class*=puisg-col] [role=button][aria-label*=ompare]",
    "[class*=s-product-image] [data-csa-c-content-id*=ompare]",
    "[class*=puisg-col] [data-csa-c-content-id*=ompare]",
]
leaked = [selector for selector in retired_shopping_selectors if selector in fixes_css]
if leaked:
    print("checkbox-stock-435 fixture: FAIL (retired Shopping white-silhouette CSS: " + ", ".join(leaked) + ")")
    raise SystemExit(1)
for preserved in ["'[class*=copilot-compare]'", "'[class*=a-check'+'box]'"]:
    if preserved not in fixes[css_end:]:
        print("checkbox-stock-435 fixture: FAIL (Amazon inline artwork is no longer protected: " + preserved + ")")
        raise SystemExit(1)
emitted = lint_js.literals_in(lint_js.function_body(source, "ADProbeWebJS")).replace("%%", "%")
start = emitted.index("function stockCheckbox434(){")
end = emitted.index("try{window.__AD_CHECKBOX434__=", start)
function = emitted[start:end]

fixture = r'''
class Style {
  constructor(){this.values=new Map();}
  setProperty(key,value){this.values.set(String(key),String(value));}
  getPropertyValue(key){return this.values.get(String(key))||'';}
  removeProperty(key){const value=this.getPropertyValue(key);this.values.delete(String(key));return value;}
}
function attr(element,name){return name==='class'?element.className:element.attrs.get(name);}
function matchesOne(element,selector){
  selector=selector.trim();if(!selector)return false;
  const tag=selector.match(/^[A-Za-z][A-Za-z0-9_-]*/);
  if(tag&&element.tagName!==tag[0].toUpperCase())return false;
  for(const match of selector.matchAll(/\.([A-Za-z0-9_-]+)/g))
    if(!String(element.className||'').split(/\s+/).includes(match[1]))return false;
  const pattern=/\[([^\]\s~*="']+)(?:([~*]?=)(?:"([^"]*)"|'([^']*)'|([^\]]*)))?\]/g;
  for(const match of selector.matchAll(pattern)){
    const value=attr(element,match[1]);if(value===undefined)return false;
    if(match[2]){
      const wanted=match[3]??match[4]??match[5]??'',actual=String(value);
      if(match[2]==='='&&actual!==wanted)return false;
      if(match[2]==='*='&&!actual.includes(wanted))return false;
      if(match[2]==='~='&&!actual.split(/\s+/).includes(wanted))return false;
    }
  }
  return true;
}
function matchesAny(element,selector){return selector.split(',').some(item=>matchesOne(element,item));}
class Element {
  constructor(tag,attrs={}){
    this.tagName=tag.toUpperCase();this.nodeType=1;this.attrs=new Map();this.children=[];
    this.parentElement=null;this.parentNode=null;this.style=new Style();this.className='';
    this.textContent='';this.innerText='';this.listeners={};this.checked=false;
    this.rect={width:32,height:32,left:0,top:0,right:32,bottom:32};
    for(const [key,value] of Object.entries(attrs))this.setAttribute(key,value);
  }
  set id(value){this.setAttribute('id',value);} get id(){return this.getAttribute('id')||'';}
  setAttribute(key,value){
    this.attrs.set(key,String(value));
    if(key==='class')this.className=String(value);
    if(key==='type')this.type=String(value);
    if(key==='src'){this.src=String(value);this.currentSrc=String(value);}
  }
  getAttribute(key){const value=attr(this,key);return value===undefined?null:value;}
  hasAttribute(key){return key==='class'?!!this.className:this.attrs.has(key);}
  removeAttribute(key){this.attrs.delete(key);if(key==='class')this.className='';}
  appendChild(child){child.parentElement=this;child.parentNode=this;this.children.push(child);return child;}
  removeChild(child){const index=this.children.indexOf(child);if(index>=0)this.children.splice(index,1);child.parentElement=child.parentNode=null;return child;}
  getBoundingClientRect(){return this.rect;}
  matches(selector){return matchesAny(this,selector);}
  closest(selector){for(let node=this;node;node=node.parentElement)if(matchesAny(node,selector))return node;return null;}
  querySelectorAll(selector){const out=[];for(const child of this.children){if(matchesAny(child,selector))out.push(child);out.push(...child.querySelectorAll(selector));}return out;}
  querySelector(selector){return this.querySelectorAll(selector)[0]||null;}
  contains(target){for(let node=target;node;node=node.parentElement)if(node===this)return true;return false;}
  addEventListener(type,handler){(this.listeners[type]??=[]).push(handler);}
  click(){
    if(this.tagName==='INPUT'&&String(this.type).toLowerCase()==='checkbox')this.checked=!this.checked;
    for(const handler of this.listeners.click||[])handler({target:this});
  }
}
class Document {
  constructor(){this.documentElement=new Element('html');this.head=new Element('head');this.body=new Element('body');this.documentElement.appendChild(this.head);this.documentElement.appendChild(this.body);}
  createElement(tag){return new Element(tag);}
  querySelectorAll(selector){const out=[];for(const root of [this.head,this.body]){if(matchesAny(root,selector))out.push(root);out.push(...root.querySelectorAll(selector));}return out;}
  querySelector(selector){return this.querySelectorAll(selector)[0]||null;}
  getElementById(id){return this.querySelector('[id="'+id+'"]');}
  addEventListener(){}
}
global.window=global;global.document=new Document();global.__ADFRAME_MODE__=false;
global.getComputedStyle=(element,pseudo)=>{
  const raw=key=>element.style.getPropertyValue(key);
  let filter=raw('filter')||'none';
  const state=element.getAttribute&&element.getAttribute('data-ad-checkbox434-art');
  if(state==='unchecked')filter='invert(1)';else if(state==='checked')filter='none';
  return {
    backgroundImage:pseudo==='::before'?(element.pseudoBeforeBackgroundImage||'none'):pseudo==='::after'?(element.pseudoAfterBackgroundImage||'none'):(raw('background-image')||'none'),maskImage:raw('mask-image')||'none',
    webkitMaskImage:raw('-webkit-mask-image')||'none',opacity:raw('opacity')||'1',
    visibility:raw('visibility')||'visible',filter,
    getPropertyValue:raw
  };
};
function element(tag,attrs={},width=32,height=32){const e=new Element(tag,attrs);e.rect={width,height,left:0,top:0,right:width,bottom:height};return e;}
function assert(value,message){if(!value)throw new Error(message);}
function noLayoutWrites(element,label){
  for(const property of ['width','height','min-width','min-height','max-width','max-height','position','inset','top','right','bottom','left','transform','margin','padding','border-radius','display','pointer-events'])
    assert(element.style.getPropertyValue(property)==='',label+' layout write: '+property);
}

for(const id of ['adstock403','adcomparenative428','adcheckbox433'])document.head.appendChild(element('style',{id}));

// Cart: classic a-checkbox artwork plus a distinct gray square wrapper.
document.body.innerText='Proceed to checkout (1 item) Save for later Deselect all items';
const cartItem=element('div',{class:'sc-list-item'},300,220);
const cartShell=element('div',{class:'cart-checkbox-tap-shell'},54,54);
const cartHost=element('div',{class:'a-checkbox','data-ad-sym413':'checkbox','data-ad-product391':'checkbox'},40,40);
const cartInput=element('input',{type:'checkbox','data-ad-compareinput380':'1'},24,24);
const cartArt=element('i',{class:'a-icon a-icon-checkbox','data-ad-stockglyph403':'c'},24,24);
const synthetic=element('span',{'data-ad-comparebox377':'1'},24,24);
cartInput.checked=false;
cartShell.style.setProperty('background-color','rgb(140,140,140)');
cartShell.style.setProperty('border','1px solid rgb(90,90,90)');
cartInput.style.setProperty('opacity','0');cartInput.style.setProperty('position','absolute');
cartArt.style.setProperty('opacity','0');cartArt.style.setProperty('filter','brightness(0)');
cartHost.appendChild(cartInput);cartHost.appendChild(cartArt);cartHost.appendChild(synthetic);
cartShell.appendChild(cartHost);cartItem.appendChild(cartShell);document.body.appendChild(cartItem);
const cartForeignToggle=element('input',{type:'checkbox',class:'cart-page-unrelated-toggle'},28,28);document.body.appendChild(cartForeignToggle);
let cartNativeCalls=0,cartPane=false;
cartInput.addEventListener('click',()=>{cartNativeCalls++;cartPane=true;});

const cartCount=stockCheckbox434();
assert(cartCount===1,'Cart classic checkbox was not discovered: count='+cartCount+' state='+String(global.__AD_CHECKBOX434_STATE__));
for(const id of ['adstock403','adcomparenative428','adcheckbox433'])assert(!document.getElementById(id),'retired stylesheet survived: '+id);
assert(cartArt.getAttribute('data-ad-checkbox434-art')==='unchecked','Cart unchecked artwork was not inverted');
assert(getComputedStyle(cartArt).filter.includes('invert'),'Cart unchecked artwork computed filter is not inverted');
assert(cartShell.getAttribute('data-ad-checkbox434-shell')==='cart','Cart gray wrapper was not neutralized');
assert(cartHost.getAttribute('data-ad-checkbox434-shell')==='cart','Cart stock host shell was not neutralized');
assert(!cartForeignToggle.hasAttribute('data-ad-checkbox434-art'),'Cart mode leaked into a page-wide checkbox');
assert(!cartHost.querySelector('[data-ad-comparebox377]'),'synthetic checkbox painter survived');
assert(cartInput.style.getPropertyValue('opacity')===''&&cartInput.style.getPropertyValue('position')==='','legacy input hiding survived');
assert(cartArt.style.getPropertyValue('opacity')===''&&cartArt.style.getPropertyValue('filter')==='','legacy sprite hiding/filter survived');
noLayoutWrites(cartShell,'Cart outer shell');noLayoutWrites(cartHost,'Cart stock shell');noLayoutWrites(cartArt,'Cart art');

cartInput.click();
assert(cartNativeCalls===1&&cartPane&&cartInput.checked,'Cart native handler/default did not survive');
stockCheckbox434();
assert(cartArt.getAttribute('data-ad-checkbox434-art')==='checked','Cart checked stock sprite was not released');
assert(getComputedStyle(cartArt).filter==='none','Cart blue checked sprite was altered');

document.body.removeChild(cartItem);document.body.removeChild(cartForeignToggle);
document.body.innerText='Search results for furniture leveling feet';

// Search result: hidden native input drives state; a sibling background image is
// the stock artwork. This is the recycled-row shape v5.433 failed to reach.
function backgroundResult(asin){
  const card=element('div',{class:'s-result-item','data-component-type':'s-search-result','data-asin':asin},360,260);
  const control=element('div',{class:'compare-selection-control'},44,44);
  const input=element('input',{type:'checkbox','data-ad-compareinput379':'1'},24,24);
  const art=element('span',{class:'selection-glyph','data-ad-productglyph391':'1'},24,24);
  input.checked=false;input.style.setProperty('opacity','0');
  art.style.setProperty('background-image','url(stock-checkbox-off.png)');art.style.setProperty('opacity','0');
  input.addEventListener('click',()=>art.style.setProperty('background-image',input.checked?'url(stock-checkbox-on.png)':'url(stock-checkbox-off.png)'));
  control.appendChild(input);control.appendChild(art);card.appendChild(control);document.body.appendChild(card);
  return {card,control,input,art};
}
const recycled=backgroundResult('SEARCH-1');
let searchNativeCalls=0,searchPane=false;
recycled.input.addEventListener('click',()=>{searchNativeCalls++;searchPane=true;});
assert(stockCheckbox434()===1,'recycled search-result checkbox was not discovered');
assert(recycled.art.getAttribute('data-ad-checkbox434-art')==='unchecked','recycled background artwork was not selected');
assert(!recycled.input.hasAttribute('data-ad-checkbox434-art')&&!recycled.control.hasAttribute('data-ad-checkbox434-art'),'filter landed on hidden input or wrapper');
assert(recycled.input.style.getPropertyValue('opacity')===''&&recycled.art.style.getPropertyValue('opacity')==='','recycled legacy hiding survived');
assert(recycled.art.style.getPropertyValue('background-image')==='url(stock-checkbox-off.png)','unchecked stock sprite URL was erased');
assert(getComputedStyle(recycled.art).filter.includes('invert'),'recycled unchecked artwork is not inverted');
recycled.input.click();stockCheckbox434();
assert(searchNativeCalls===1&&searchPane&&recycled.input.checked,'recycled native Compare action/pane did not survive');
assert(recycled.art.getAttribute('data-ad-checkbox434-art')==='checked','recycled checked artwork did not follow native state');
assert(recycled.art.style.getPropertyValue('background-image')==='url(stock-checkbox-on.png)','checked stock sprite URL was erased');
assert(getComputedStyle(recycled.art).filter==='none','recycled blue checked sprite was inverted');

// Native-input-only result: the input itself is the stock art and must remain native.
const inputCard=element('div',{class:'puis-card','data-asin':'SEARCH-2'},360,260);
const inputControl=element('label',{class:'compare-input-shell'},44,44);
const visibleInput=element('input',{type:'checkbox'},26,26);visibleInput.checked=false;
inputControl.appendChild(visibleInput);inputCard.appendChild(inputControl);document.body.appendChild(inputCard);
assert(stockCheckbox434()===2,'native-input-only result was not discovered');
assert(visibleInput.getAttribute('data-ad-checkbox434-art')==='unchecked','visible native input is not the artwork owner');
visibleInput.click();stockCheckbox434();
assert(visibleInput.getAttribute('data-ad-checkbox434-art')==='checked'&&getComputedStyle(visibleInput).filter==='none','visible native checked sprite was altered');

// Wrapper-pseudo result: the visible stock square is ::before while a hidden
// native input remains the state owner. The wrapper, not the input, gets filter.
const pseudoCard=element('div',{class:'puis-card','data-asin':'SEARCH-PSEUDO'},360,260);
const pseudoControl=element('label',{class:'compare-checkbox-shell'},40,40);
const pseudoInput=element('input',{type:'checkbox'},24,24);pseudoInput.checked=false;pseudoInput.style.setProperty('opacity','0');
pseudoControl.pseudoBeforeBackgroundImage='url(stock-checkbox-off.png)';pseudoControl.appendChild(pseudoInput);pseudoCard.appendChild(pseudoControl);document.body.appendChild(pseudoCard);
pseudoInput.addEventListener('click',()=>pseudoControl.pseudoBeforeBackgroundImage=pseudoInput.checked?'url(stock-checkbox-on.png)':'url(stock-checkbox-off.png)');
assert(stockCheckbox434()===3,'wrapper-pseudo stock artwork was not discovered');
assert(pseudoControl.getAttribute('data-ad-checkbox434-art')==='unchecked'&&!pseudoInput.hasAttribute('data-ad-checkbox434-art'),'pseudo filter landed on invisible native input');
pseudoInput.click();stockCheckbox434();
assert(pseudoControl.getAttribute('data-ad-checkbox434-art')==='checked'&&getComputedStyle(pseudoControl).filter==='none','wrapper-pseudo blue sprite was altered');

// A new role-checkbox row appears after scrolling/recycling. It must be picked up
// on the next pass without changing the two already-live controls.
const roleCard=element('div',{class:'puis-card','data-asin':'SEARCH-3'},360,260);
const roleControl=element('div',{class:'copilot-compare on-image-button compare-role-control',role:'checkbox','aria-label':'Compare','aria-checked':'false','data-csa-c-content-id':'compare'},38,38);
const roleArt=element('span',{class:'compare-role-glyph'},24,24);roleArt.style.setProperty('background-image','url(stock-checkbox-off.png)');
roleControl.appendChild(roleArt);roleCard.appendChild(roleControl);document.body.appendChild(roleCard);
roleControl.addEventListener('click',()=>{const on=roleControl.getAttribute('aria-checked')!=='true';roleControl.setAttribute('aria-checked',on?'true':'false');roleArt.style.setProperty('background-image',on?'url(stock-checkbox-on.png)':'url(stock-checkbox-off.png)');});
assert(stockCheckbox434()===4,'newly recycled role-checkbox row was not discovered');
assert(roleArt.getAttribute('data-ad-checkbox434-art')==='unchecked','role-checkbox artwork was not selected');
roleControl.click();stockCheckbox434();
assert(roleArt.getAttribute('data-ad-checkbox434-art')==='checked'&&getComputedStyle(roleArt).filter==='none','role-checkbox blue sprite was altered');
assert(recycled.art.getAttribute('data-ad-checkbox434-art')==='checked'&&visibleInput.getAttribute('data-ad-checkbox434-art')==='checked','recycling dropped existing Compare artwork');

function excluded(rootClass,extra={}){
  const card=element('div',{class:'puis-card'},360,200),root=element('div',{class:rootClass,...extra},50,50);
  const box=element('div',{class:'a-checkbox'},36,36),q=element('input',{type:'checkbox'},24,24),art=element('i',{class:'a-icon-checkbox'},24,24);
  box.appendChild(q);box.appendChild(art);root.appendChild(box);card.appendChild(root);document.body.appendChild(card);
  return {box,q,art};
}
const excludedControls=[
  excluded('mlt-icon-container'),excluded('lists-framework-action-button'),
  excluded('puis-heart-position'),excluded('lists-treatment-heart'),
  excluded('puis-mab-chevron'),excluded('cards-backdrop',{'data-ad-cards410-root':'1'})
];
const primeToggle=element('input',{type:'checkbox',class:'prime-filter-toggle'},28,28);document.body.appendChild(primeToggle);
const unrelated=element('i',{class:'a-icon-heart'},24,24);unrelated.style.setProperty('filter','heart-lock');document.body.appendChild(unrelated);
assert(stockCheckbox434()===4,'foreign or out-of-scope checkbox was counted as Compare');
for(const item of excludedControls){
  assert(!item.art.hasAttribute('data-ad-checkbox434-art')&&!item.q.hasAttribute('data-ad-checkbox434-art')&&!item.box.hasAttribute('data-ad-checkbox434-art'),'filter leaked into another icon family');
}
assert(!primeToggle.hasAttribute('data-ad-checkbox434-art'),'out-of-card Prime toggle was inverted');
assert(unrelated.style.getPropertyValue('filter')==='heart-lock','unrelated Heart icon changed');

const css=document.getElementById('adcheckbox434').textContent;
const expected='[data-ad-checkbox434-art="unchecked"]{filter:invert(1) !important;}[data-ad-checkbox434-art="checked"]{filter:none !important;}[data-ad-checkbox434-shell="cart"]{background-color:transparent !important;background-image:none !important;border:0 !important;box-shadow:none !important;outline:0 !important;}[data-ad-checkbox434-shell="cart"]::before,[data-ad-checkbox434-shell="cart"]::after{background-color:transparent !important;background-image:none !important;border:0 !important;box-shadow:none !important;outline:0 !important;}';
assert(css===expected,'stylesheet escaped the stock-art/cart-shell contract');
const artRules=[...css.matchAll(/\[data-ad-checkbox434-art[^}]+\{([^}]*)\}/g)];
assert(artRules.length===2&&artRules.every(rule=>rule[1].split(';').filter(Boolean).every(decl=>decl.trim().startsWith('filter:'))),'art rules contain paint or geometry');
const shellRules=[...css.matchAll(/(?:\[data-ad-checkbox434-shell[^}]+)(?:\{)([^}]*)\}/g)];
const shellAllowed=new Set(['background-color','background-image','border','box-shadow','outline']);
assert(shellRules.length===2&&shellRules.every(rule=>rule[1].split(';').filter(Boolean).every(decl=>shellAllowed.has(decl.split(':')[0].trim()))),'Cart shell writes geometry or non-neutral paint');
assert(!/(?:width|height|position|inset|transform|margin|padding|border-radius|display|pointer-events)\s*:/i.test(css),'stylesheet changes checkbox geometry/hit target');
assert(document.head.querySelectorAll('[id="adcheckbox434"]').length===1,'stylesheet duplicated');

console.log('checkbox-stock-435 fixture: PASS (byte-locked Cart; no Shopping white-silhouette override; classic/background/input/pseudo/role art; native pane/state; blue sprite; icon exclusions)');
'''

result = subprocess.run([NODE, "-e", function + fixture], text=True, capture_output=True)
if result.stdout:
    print(result.stdout, end="")
if result.stderr:
    print(result.stderr, end="", file=sys.stderr)
raise SystemExit(result.returncode)

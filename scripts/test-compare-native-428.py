#!/usr/bin/env python3
"""Exercise the v5.441 device-captured cards/checkbox ownership contract."""
from pathlib import Path
import importlib.util
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "src/Tweak.xm"
NODE = shutil.which("node")

if not NODE:
    print("icon-ownership-441 fixture: SKIP (node not installed)")
    raise SystemExit(0)

spec = importlib.util.spec_from_file_location("lint_js", ROOT / "scripts/lint-js.py")
lint_js = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lint_js)
source = SOURCE.read_text(encoding="utf-8")
fixes = lint_js.literals_in(lint_js.function_body(source, "ADFixesLiteral")).replace("%%", "%")
css_start = fixes.index("{css:'") + len("{css:'")
css_end = fixes.index("',invert:", css_start)
fixes_css = fixes[css_start:css_end]
first_paint_required = [
    ".a-checkbox:not(:has(input[type=checkbox]:checked)) i.a-icon-checkbox",
    "filter:none !important;border-radius:50% !important;",
    "box-shadow:inset 0 0 0 64px #181a1b,0 0 0 3px #181a1b,0 0 0 4.5px rgba(255,255,255,.65) !important;",
    ".a-checkbox:has(input[type=checkbox]:checked) i.a-icon-checkbox",
    "filter:none !important;border-radius:0 !important;box-shadow:none !important;",
    ".sc-item-checkbox .a-checkbox>label",
]
missing_first_paint = [token for token in first_paint_required if token not in fixes_css]
if missing_first_paint:
    print("icon-ownership-441 fixture: FAIL (documentStart checkbox contract missing: " + ", ".join(missing_first_paint) + ")")
    raise SystemExit(1)
if any(token in fixes_css for token in ["background-position:", "background-image:url(", ".s-coupon-checkbox"]):
    print("icon-ownership-441 fixture: FAIL (first-paint contract alters the sprite or coupon controls)")
    raise SystemExit(1)
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
    print("icon-ownership-441 fixture: FAIL (retired Shopping white-silhouette CSS: " + ", ".join(leaked) + ")")
    raise SystemExit(1)
for preserved in ["'[class*=copilot-compare]'", "'[class*=a-check'+'box]'"]:
    if preserved not in fixes[css_end:]:
        print("icon-ownership-441 fixture: FAIL (Amazon inline artwork is no longer protected: " + preserved + ")")
        raise SystemExit(1)
checkbox_guard = "closest('[class*=a-checkbox],[class*=a-icon-checkbox],input[type=checkbox],[role=checkbox],[class*=copilot-compare],button[aria-label*=ompare],[data-csa-c-content-id*=ompare]')"
if checkbox_guard not in source:
    print("icon-ownership-441 fixture: FAIL (broad glyph writer can still enter a native checkbox subtree)")
    raise SystemExit(1)
emitted = lint_js.literals_in(lint_js.function_body(source, "ADProbeWebJS")).replace("%%", "%")
start = emitted.index("function stockCheckbox434(){")
end = emitted.index("try{window.__AD_CHECKBOX434__=", start)
function = emitted[start:end]
sym_start = emitted.index("function sym413(){")
sym_end = emitted.index("try{window.__AD_SYM413_PRE__=", sym_start)
sym_function = emitted[sym_start:sym_end]

fixture = r'''
class Style {
  constructor(){this.values=new Map();this.priorities=new Map();}
  setProperty(key,value,priority=''){this.values.set(String(key),String(value));this.priorities.set(String(key),String(priority));}
  getPropertyValue(key){return this.values.get(String(key))||'';}
  getPropertyPriority(key){return this.priorities.get(String(key))||'';}
  removeProperty(key){const value=this.getPropertyValue(key);this.values.delete(String(key));this.priorities.delete(String(key));return value;}
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
function nativeSelected434(element){
  const host=element.closest&&element.closest('[data-ad-checkbox434-host]')||element;
  const input=(host.matches&&host.matches('input[type=checkbox]'))?host:host.querySelector&&host.querySelector('input[type=checkbox]');
  if(input)return !!input.checked;
  const nodes=[host,...(host.querySelectorAll?host.querySelectorAll('[role=checkbox],[aria-checked],[aria-pressed],[aria-selected],[data-checked],[data-selected],[data-state]'):[])];
  for(const node of nodes){
    const value=String(node.getAttribute('aria-checked')||node.getAttribute('aria-pressed')||node.getAttribute('aria-selected')||node.getAttribute('data-checked')||node.getAttribute('data-selected')||node.getAttribute('data-state')||'').toLowerCase();
    const cls=String(node.className||'').toLowerCase();
    if(value==='true'||value==='checked'||value==='on'||(/checked|selected/.test(cls)&&!/unchecked|unselected/.test(cls)))return true;
    if(value==='false'||value==='unchecked'||value==='off')return false;
  }
  const src=String(element.currentSrc||element.src||element.getAttribute&&element.getAttribute('data-src')||'').toLowerCase();
  return /checkbox[_-]?(?:on|checked)|checkmark|selected/.test(src)&&!/unchecked|unselected/.test(src);
}
global.getComputedStyle=(element,pseudo)=>{
  const raw=key=>element.style.getPropertyValue(key);
  let filter=raw('filter')||'none';
  if(element.hasAttribute&&element.hasAttribute('data-ad-checkbox434-art')&&!raw('filter'))filter='none';
  if(element.getAttribute&&element.getAttribute('data-ad-checkbox434-shell')==='cart')filter='none';
  const shell=element.getAttribute&&element.getAttribute('data-ad-checkbox434-shell')==='cart';
  const checkboxArt=element.hasAttribute&&element.hasAttribute('data-ad-checkbox434-art');
  const selected=checkboxArt&&nativeSelected434(element);
  return {
    backgroundImage:pseudo==='::before'?(element.pseudoBeforeBackgroundImage||'none'):pseudo==='::after'?(element.pseudoAfterBackgroundImage||'none'):(raw('background-image')||'none'),maskImage:raw('mask-image')||'none',
    webkitMaskImage:raw('-webkit-mask-image')||'none',opacity:raw('opacity')||'1',
    visibility:raw('visibility')||'visible',display:raw('display')||'block',appearance:raw('appearance')||'auto',webkitAppearance:raw('-webkit-appearance')||'auto',filter,
    backgroundColor:shell?'transparent':(raw('background-color')||'transparent'),
    borderTopWidth:shell?'0px':(raw('border-width')||'0px'),
    borderRadius:checkboxArt?(selected?'0px':'50%'):(raw('border-radius')||'0px'),
    boxShadow:shell?'none':(checkboxArt?(selected?'none':'rgb(24, 26, 27) 0px 0px 0px 64px inset, rgb(24, 26, 27) 0px 0px 0px 3px, rgba(255, 255, 255, 0.65) 0px 0px 0px 4.5px'):(raw('box-shadow')||'none')),
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

// Cart: Amazon owns the input and sprite. Two paint-only square wrappers model
// the extra gray ring seen on-device; both must be neutralized without geometry.
document.body.innerText='Proceed to checkout (1 item) Save for later Deselect all items';
const cartItem=element('div',{class:'sc-list-item'},300,220);
const cartShell=element('div',{class:'cart-checkbox-tap-shell'},54,54);
const cartHost=element('div',{class:'a-checkbox','data-ad-sym413':'checkbox','data-ad-product391':'checkbox'},398,0);
const cartLabel=element('label',{},35,44);
const cartInput=element('input',{type:'checkbox','data-ad-compareinput380':'1'},24,24);
const cartArt=element('i',{class:'a-icon a-icon-checkbox','data-ad-stockglyph403':'c'},24,24);
const synthetic=element('span',{'data-ad-comparebox377':'1'},24,24);
cartInput.checked=false;
cartShell.style.setProperty('background-color','rgb(140,140,140)');cartShell.style.setProperty('border','1px solid rgb(90,90,90)');
cartLabel.style.setProperty('background-color','rgb(120,120,120)');cartLabel.style.setProperty('box-shadow','0 0 0 2px gray');
cartInput.style.setProperty('opacity','0');cartInput.style.setProperty('position','absolute');
cartArt.style.setProperty('background-image','url(stock-checkbox-off.png)');cartArt.style.setProperty('opacity','0');cartArt.style.setProperty('filter','brightness(0)');
cartLabel.appendChild(cartInput);cartLabel.appendChild(cartArt);cartLabel.appendChild(synthetic);cartHost.appendChild(cartLabel);cartShell.appendChild(cartHost);cartItem.appendChild(cartShell);document.body.appendChild(cartItem);
const cartForeignToggle=element('input',{type:'checkbox',class:'cart-page-unrelated-toggle'},28,28);document.body.appendChild(cartForeignToggle);
let cartNativeCalls=0,cartPane=false;
cartInput.addEventListener('click',()=>{cartNativeCalls++;cartPane=true;cartArt.style.setProperty('background-image',cartInput.checked?'url(stock-checkbox-on.png)':'url(stock-checkbox-off.png)');});

const cartCount=stockCheckbox434();
assert(cartCount===1,'Cart classic checkbox was not discovered: count='+cartCount+' state='+String(global.__AD_CHECKBOX434_STATE__));
for(const id of ['adstock403','adcomparenative428','adcheckbox433'])assert(!document.getElementById(id),'retired stylesheet survived: '+id);
assert(cartHost.getAttribute('data-ad-checkbox434-host')==='stock','Cart native host was not marked');
assert(cartArt.getAttribute('data-ad-checkbox434-art')==='stock','Cart stock sprite was not selected');
assert(getComputedStyle(cartArt).filter==='none','Cart unchecked stock sprite was filtered instead of paint-covered');
assert(cartLabel.getAttribute('data-ad-checkbox434-shell')==='cart','Cart 35x44 gray label was not neutralized');
assert(getComputedStyle(cartLabel).borderTopWidth==='0px'&&getComputedStyle(cartLabel).boxShadow==='none','Cart gray rectangle survived computed shell cleanup');
assert(getComputedStyle(cartArt).borderRadius==='50%'&&getComputedStyle(cartArt).boxShadow.includes('0px 0px 0px 4.5px'),'Cart unchecked sprite lacks the canonical 32px dark/chrome treatment');
assert(!cartForeignToggle.hasAttribute('data-ad-checkbox434-art'),'Cart mode leaked into a page-wide checkbox');
assert(!cartHost.querySelector('[data-ad-comparebox377]'),'synthetic checkbox painter survived');
assert(cartInput.style.getPropertyValue('opacity')===''&&cartInput.style.getPropertyValue('position')==='','legacy input hiding survived');
assert(cartArt.style.getPropertyValue('opacity')===''&&cartArt.style.getPropertyValue('filter')==='','legacy sprite hiding/filter survived');
noLayoutWrites(cartShell,'Cart outer shell');noLayoutWrites(cartHost,'Cart stock row');noLayoutWrites(cartLabel,'Cart label');noLayoutWrites(cartArt,'Cart art');

// No repaint call after click: native :checked must release the filter in the same
// frame, leaving Amazon's blue/checkmark sprite stock and preventing orange flash.
cartInput.click();
assert(cartNativeCalls===1&&cartPane&&cartInput.checked,'Cart native handler/default did not survive');
assert(cartArt.style.getPropertyValue('background-image')==='url(stock-checkbox-on.png)','Cart checked stock sprite URL was erased');
assert(getComputedStyle(cartArt).filter==='none','Cart blue checked sprite waited for JavaScript or was inverted orange');
assert(getComputedStyle(cartArt).boxShadow==='none'&&getComputedStyle(cartArt).borderRadius==='0px','Cart checked state retained custom chrome around Amazon blue');
cartInput.click();
assert(!cartInput.checked&&getComputedStyle(cartArt).boxShadow.includes('64px inset'),'Cart native uncheck did not synchronously restore #181a1b paint');

document.body.removeChild(cartItem);document.body.removeChild(cartForeignToggle);
document.body.innerText='Search results for furniture leveling feet';

// Shopping/scrolling shape: the semantic control is role=button/copilot, not
// role=checkbox. This reproduces the device capture: the visible art is Amazon's
// 23px i.a-icon.a-icon-checkbox sprite and a broad glyph writer previously left
// brightness(0) invert(1) inline, turning it into a white box. Discovery must
// clear that tweak-owned write and leave the stock sprite as the sole artwork.
function shoppingResult(asin){
  const card=element('div',{class:'s-result-item','data-component-type':'s-search-result','data-asin':asin},360,260);
  const control=element('div',{class:'copilot-compare compare-control'},44,44);
  const button=element('button',{class:'on-image-button','aria-label':'Compare','data-csa-c-content-id':'compare'},40,40);
  const input=element('input',{type:'checkbox'},24,24);input.checked=false;input.style.setProperty('opacity','0');
  const hidden=element('span',{class:'legacy-hidden-art'},24,24);hidden.style.setProperty('opacity','0');
  const art=element('i',{class:'a-icon a-icon-checkbox'},23,23);art.style.setProperty('background-image','url(stock-checkbox-off.png)');
  art.style.setProperty('filter','brightness(0) invert(1)','important');art.__adBy='gfix1';art.__adGlyph=1;
  input.addEventListener('click',()=>art.style.setProperty('background-image',input.checked?'url(stock-checkbox-on.png)':'url(stock-checkbox-off.png)'));
  button.appendChild(input);button.appendChild(hidden);button.appendChild(art);control.appendChild(button);card.appendChild(control);document.body.appendChild(card);
  return {card,control,button,input,hidden,art};
}
const shopping=shoppingResult('SEARCH-1');
let shoppingNativeCalls=0,shoppingPane=false;
shopping.input.addEventListener('click',()=>{shoppingNativeCalls++;shoppingPane=true;});
assert(stockCheckbox434()===1,'Shopping role-button checkbox was not discovered: '+String(global.__AD_CHECKBOX434_STATE__));
assert(shopping.control.getAttribute('data-ad-checkbox434-host')==='stock','Shopping semantic host was not canonicalized');
assert(shopping.art.getAttribute('data-ad-checkbox434-art')==='stock','Shopping visible background sprite was not selected');
assert(!shopping.hidden.hasAttribute('data-ad-checkbox434-art')&&!shopping.input.hasAttribute('data-ad-checkbox434-art'),'Shopping filter landed on hidden art/input');
assert(shopping.art.style.getPropertyValue('filter')===''&&shopping.art.style.getPropertyPriority('filter')==='','Shopping stale broad-writer filter survived cleanup');
assert(getComputedStyle(shopping.art).filter==='none'&&getComputedStyle(shopping.art).boxShadow.includes('64px inset'),'Shopping unchecked white sprite was not covered with #181a1b');
assert(getComputedStyle(shopping.art).borderRadius==='50%'&&getComputedStyle(shopping.art).boxShadow.includes('rgb(24, 26, 27)'),'Shopping unchecked sprite lacks canonical circular chrome');
assert(shopping.art.style.getPropertyValue('background-image')==='url(stock-checkbox-off.png)','Shopping unchecked stock sprite was replaced');
shopping.input.click();
assert(shoppingNativeCalls===1&&shoppingPane&&shopping.input.checked,'Shopping native Compare action/pane did not survive');
assert(shopping.art.style.getPropertyValue('background-image')==='url(stock-checkbox-on.png)','Shopping checked stock sprite did not render');
assert(getComputedStyle(shopping.art).filter==='none','Shopping blue sprite waited for repaint or flashed orange');
assert(getComputedStyle(shopping.art).boxShadow==='none','Shopping checked stock blue sprite retained custom chrome');

// A second row appears during scrolling. The next discovery pass must pick it up
// while the already-selected row keeps native state and stock artwork.
const scrolling=shoppingResult('SEARCH-2');
assert(stockCheckbox434()===2,'newly recycled Shopping row was not discovered');
assert(scrolling.art.getAttribute('data-ad-checkbox434-art')==='stock'&&getComputedStyle(scrolling.art).boxShadow.includes('64px inset'),'recycled Shopping checkbox did not render #181a1b');
assert(shopping.art.getAttribute('data-ad-checkbox434-art')==='stock'&&getComputedStyle(shopping.art).filter==='none','recycling regressed the selected Shopping sprite');

// Some Shopping builds expose a button with aria-pressed and no native input.
// ARIA state must also release the filter synchronously, without a JS state tag.
const ariaCard=element('div',{class:'puis-card','data-asin':'SEARCH-ARIA'},360,240);
const ariaControl=element('button',{class:'copilot-compare on-image-button','aria-label':'Compare','aria-pressed':'false'},40,40);
const ariaArt=element('span',{class:'compare-role-glyph'},24,24);ariaArt.style.setProperty('background-image','url(stock-checkbox-off.png)');
ariaControl.appendChild(ariaArt);ariaCard.appendChild(ariaControl);document.body.appendChild(ariaCard);
ariaControl.addEventListener('click',()=>{const on=ariaControl.getAttribute('aria-pressed')!=='true';ariaControl.setAttribute('aria-pressed',on?'true':'false');ariaArt.style.setProperty('background-image',on?'url(stock-checkbox-on.png)':'url(stock-checkbox-off.png)');});
assert(stockCheckbox434()===3,'Shopping aria-pressed Compare control was not discovered');
assert(ariaArt.getAttribute('data-ad-checkbox434-art')==='stock'&&getComputedStyle(ariaArt).boxShadow.includes('64px inset'),'ARIA unchecked stock art was not painted #181a1b');
ariaControl.click();
assert(getComputedStyle(ariaArt).filter==='none'&&ariaArt.style.getPropertyValue('background-image')==='url(stock-checkbox-on.png)','ARIA checked blue sprite was altered or delayed');

// A Shopping variant paints the stock square as a plain white background while
// keeping an a-icon-checkbox node hidden. The visible light box, not that hidden
// leaf, must own inversion; native :checked then exposes the blue background.
const solidCard=element('div',{class:'puis-card','data-asin':'SEARCH-SOLID'},360,240);
const solidControl=element('div',{class:'copilot-compare compare-control'},44,44);
const solidButton=element('button',{class:'on-image-button','aria-label':'Compare'},40,40);solidButton.style.setProperty('background-color','rgb(255,255,255)');
const solidInput=element('input',{type:'checkbox'},24,24);solidInput.style.setProperty('opacity','0');
const solidHidden=element('i',{class:'a-icon a-icon-checkbox'},24,24);solidHidden.style.setProperty('opacity','0');
solidInput.addEventListener('click',()=>solidButton.style.setProperty('background-color',solidInput.checked?'rgb(33,98,161)':'rgb(255,255,255)'));
solidButton.appendChild(solidInput);solidButton.appendChild(solidHidden);solidControl.appendChild(solidButton);solidCard.appendChild(solidControl);document.body.appendChild(solidCard);
assert(stockCheckbox434()===4,'solid-white Shopping checkbox was not discovered');
assert(solidButton.getAttribute('data-ad-checkbox434-art')==='stock'&&!solidHidden.hasAttribute('data-ad-checkbox434-art'),'solid-white Shopping filter landed on hidden sprite');
assert(getComputedStyle(solidButton).filter==='none'&&getComputedStyle(solidButton).boxShadow.includes('64px inset'),'solid-white Shopping box did not render #181a1b');
solidInput.click();
assert(getComputedStyle(solidButton).filter==='none'&&getComputedStyle(solidButton).backgroundColor==='rgb(33,98,161)','solid-white Shopping checked sprite was altered or delayed');

// Wrapper-pseudo result: the stock square is ::before and the hidden native
// input owns state. Filtering the wrapper is correct; it must not be mistaken
// for a Cart ring and must release on :checked without running discovery again.
const pseudoCard=element('div',{class:'puis-card','data-asin':'SEARCH-PSEUDO'},360,240);
const pseudoControl=element('label',{class:'compare-checkbox-shell'},40,40);
const pseudoInput=element('input',{type:'checkbox'},24,24);pseudoInput.checked=false;pseudoInput.style.setProperty('opacity','0');
pseudoControl.pseudoBeforeBackgroundImage='url(stock-checkbox-off.png)';pseudoControl.appendChild(pseudoInput);pseudoCard.appendChild(pseudoControl);document.body.appendChild(pseudoCard);
pseudoInput.addEventListener('click',()=>pseudoControl.pseudoBeforeBackgroundImage=pseudoInput.checked?'url(stock-checkbox-on.png)':'url(stock-checkbox-off.png)');
assert(stockCheckbox434()===5,'wrapper-pseudo stock artwork was not discovered');
assert(pseudoControl.getAttribute('data-ad-checkbox434-host')==='stock'&&pseudoControl.getAttribute('data-ad-checkbox434-art')==='stock','pseudo artwork did not remain its own native host');
assert(!pseudoInput.hasAttribute('data-ad-checkbox434-art')&&getComputedStyle(pseudoControl).boxShadow.includes('64px inset'),'pseudo paint landed on hidden native input');
pseudoInput.click();
assert(getComputedStyle(pseudoControl).filter==='none','wrapper-pseudo blue sprite was altered or timer-delayed');

// v5.441 ownership collision lock: Amazon may mount cards and checkbox families
// at the same product-image coordinates. Cards may paint only when their own
// artwork is visible and no visible stock checkbox occupies that location.
function place(e,left,top,width,height){e.rect={width,height,left,top,right:left+width,bottom:top+height};return e;}
function cardsResult(asin,left,top){
  const card=place(element('div',{class:'puis-card','data-asin':asin},360,220),0,top-20,360,220);
  const host=place(element('div',{class:'mlt-icon-container'},32,32),left,top,32,32);
  const shell=place(element('span',{class:'mlt-image-icon'},24,24),left+4,top+4,24,24);
  const glyph=place(element('img',{class:'s-image',src:'two-cards.png'},20,19),left+6,top+6,20,19);
  shell.appendChild(glyph);host.appendChild(shell);card.appendChild(host);document.body.appendChild(card);
  return {card,host,shell,glyph};
}
const activeCards=cardsResult('CARDS-ACTIVE',20,900);
const hiddenCards=cardsResult('CARDS-HIDDEN',20,1160);hiddenCards.glyph.style.setProperty('visibility','hidden');
const collision=cardsResult('CARDS-COLLISION',20,1420);
const collisionCheck=place(element('div',{class:'a-checkbox'},40,40),16,1416,40,40);
const collisionInput=place(element('input',{type:'checkbox'},24,24),20,1420,24,24);collisionInput.checked=false;
const collisionArt=place(element('i',{class:'a-icon a-icon-checkbox'},23,23),20,1420,23,23);collisionArt.style.setProperty('background-image','url(stock-checkbox-off.png)');
collisionCheck.appendChild(collisionInput);collisionCheck.appendChild(collisionArt);collision.card.appendChild(collisionCheck);

sym413();
assert(activeCards.host.getAttribute('data-ad-cards440-host')==='1','visible two-cards host was not painted');
assert(activeCards.host.style.getPropertyValue('background-color')==='#181a1b','two-cards backdrop regressed from black');
assert(activeCards.glyph.getAttribute('data-ad-cards440-glyph')==='1'&&activeCards.glyph.style.getPropertyValue('filter')==='brightness(0) invert(1)','two-cards artwork regressed from white');
assert(activeCards.glyph.style.getPropertyValue('visibility')===''&&activeCards.glyph.style.getPropertyValue('opacity')==='','cards owner forced Amazon visibility');
assert(!hiddenCards.host.hasAttribute('data-ad-cards440-host')&&!hiddenCards.glyph.hasAttribute('data-ad-cards440-glyph'),'hidden cards artwork was forced active');
assert(collision.host.getAttribute('data-ad-cards440-suppressed')==='checkbox','cards were not suppressed at a live checkbox collision');
assert(collision.host.style.getPropertyValue('visibility')==='hidden'&&collision.host.style.getPropertyValue('opacity')==='0','colliding cards subtree can still spill over checkbox');
assert(!collision.host.hasAttribute('data-ad-cards440-host')&&!collision.glyph.hasAttribute('data-ad-cards440-glyph'),'suppressed cards retained active paint ownership');

assert(stockCheckbox434()===6,'colliding stock checkbox was not independently discovered');
assert(collisionArt.getAttribute('data-ad-checkbox434-art')==='stock'&&getComputedStyle(collisionArt).boxShadow.includes('64px inset'),'collision checkbox did not retain #181a1b stock-art covering');
assert(!collisionArt.hasAttribute('data-ad-cards440-glyph')&&!collisionCheck.hasAttribute('data-ad-cards440-host'),'checkbox acquired cards ownership');
sym413();
assert(collision.host.getAttribute('data-ad-cards440-suppressed')==='checkbox','cards reappeared after checkbox discovery');

// Once Amazon removes the visible checkbox art, the same recycled cards node may
// become active again; no permanent hide or stale ownership is allowed.
collisionArt.style.setProperty('visibility','hidden');sym413();
assert(collision.host.getAttribute('data-ad-cards440-host')==='1'&&!collision.host.hasAttribute('data-ad-cards440-suppressed'),'recycled cards node stayed suppressed after checkbox disappeared');
assert(collision.host.style.getPropertyValue('visibility')===''&&collision.host.style.getPropertyValue('opacity')==='','recycled cards node retained forced hiding');
collisionArt.style.removeProperty('visibility');sym413();
assert(collision.host.getAttribute('data-ad-cards440-suppressed')==='checkbox'&&!collision.glyph.hasAttribute('data-ad-cards440-glyph'),'cards were not re-suppressed when checkbox returned');

document.body.removeChild(activeCards.card);document.body.removeChild(hiddenCards.card);document.body.removeChild(collision.card);

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
const couponCard=element('div',{class:'puis-card','data-asin':'COUPON'},360,200);
const couponInput=element('input',{type:'checkbox',class:'s-coupon-checkbox s-coupon-checkbox-native'},16,16);
couponCard.appendChild(couponInput);document.body.appendChild(couponCard);
const primeToggle=element('input',{type:'checkbox',class:'prime-filter-toggle'},28,28);document.body.appendChild(primeToggle);
const unrelated=element('i',{class:'a-icon-heart'},24,24);unrelated.style.setProperty('filter','heart-lock');document.body.appendChild(unrelated);
assert(stockCheckbox434()===5,'foreign or out-of-scope checkbox was counted as Compare');
for(const item of excludedControls)assert(!item.art.hasAttribute('data-ad-checkbox434-art')&&!item.q.hasAttribute('data-ad-checkbox434-art')&&!item.box.hasAttribute('data-ad-checkbox434-art'),'filter leaked into another icon family');
assert(!couponInput.hasAttribute('data-ad-checkbox434-art')&&!couponInput.hasAttribute('data-ad-checkbox434-host'),'product coupon checkbox was mistaken for Compare');
assert(!primeToggle.hasAttribute('data-ad-checkbox434-art'),'out-of-card Prime toggle was inverted');
assert(unrelated.style.getPropertyValue('filter')==='heart-lock','unrelated Heart icon changed');

const style=document.getElementById('adcheckbox434'),css=style.textContent;
assert(style.getAttribute('data-ad-native-state')==='443','old timer-state stylesheet survived');
assert(css.includes(':has(input[type=checkbox]:checked')&&css.includes('[aria-pressed=true]'),'native input/ARIA state selectors are missing');
assert(css.includes('[data-ad-checkbox434-art]{filter:none !important;border-radius:4px !important;box-shadow:inset 0 0 0 64px #181a1b,0 0 0 3px #181a1b,0 0 0 4.5px rgba(255,255,255,.65) !important;transition:none !important;}'),'unchecked 32px chrome stock-art rule is missing');
assert(!css.includes('[data-ad-checkbox434-art="unchecked"]')&&!css.includes('[data-ad-checkbox434-art="checked"]'),'JavaScript timer-state selectors survived');
const rules=[...css.matchAll(/([^{}]+)\{([^}]*)\}/g)];
const artRules=rules.filter(rule=>rule[1].includes('data-ad-checkbox434-art'));
const artAllowed=new Set(['filter','border-radius','box-shadow','transition']);
assert(artRules.length>=2&&artRules.every(rule=>rule[2].split(';').filter(Boolean).every(decl=>artAllowed.has(decl.split(':')[0].trim()))),'art rules change the sprite, geometry, or hit target');
const shellRules=rules.filter(rule=>rule[1].includes('data-ad-checkbox434-shell'));
const shellAllowed=new Set(['background-color','background-image','border','box-shadow','outline','filter']);
assert(shellRules.length===2&&shellRules.every(rule=>rule[2].split(';').filter(Boolean).every(decl=>shellAllowed.has(decl.split(':')[0].trim()))),'Cart shell writes geometry or non-neutral paint');
assert(!/(?:width|height|position|inset|transform|margin|padding|display|pointer-events)\s*:/i.test(css)&&!/data-ad-checkbox434-art[^}]*\{[^}]*(?:background-image|background-position)\s*:/i.test(css),'stylesheet changes checkbox sprite, geometry, or hit target');
assert(css.includes('inset 0 0 0 64px #181a1b')&&!css.includes('brightness(0)')&&!css.includes('invert(1)'),'unchecked checkbox does not use exact paint or still filters the stock sprite/chrome');
assert(document.head.querySelectorAll('[id="adcheckbox434"]').length===1,'stylesheet duplicated');
const runtime=stockCheckbox434.toString();
for(const forbidden of ['.click(','dispatchEvent','preventDefault(','stopPropagation(',"setAttribute('aria-checked'","setAttribute('data-checked'","setAttribute('data-selected'","on?'checked':'unchecked'"])
  assert(!runtime.includes(forbidden),'checkbox runtime emulates state or interaction: '+forbidden);

console.log('icon-ownership-441 fixture: PASS (spillover locked; 32px dark/chrome checkbox; no gray shell; untouched stock blue sprite; no orange timer race)');
'''

result = subprocess.run([NODE, "-e", sym_function + function + fixture], text=True, capture_output=True)
if result.stdout:
    print(result.stdout, end="")
if result.stderr:
    print(result.stderr, end="", file=sys.stderr)
raise SystemExit(result.returncode)

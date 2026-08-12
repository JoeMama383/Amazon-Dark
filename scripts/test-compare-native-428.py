#!/usr/bin/env python3
"""Exercise the emitted v5.428 Compare repair against stock DOM shapes."""
from pathlib import Path
import importlib.util
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "src/Tweak.xm"
NODE = shutil.which("node")

if not NODE:
    print("compare-native-428 fixture: SKIP (node not installed)")
    raise SystemExit(0)

spec = importlib.util.spec_from_file_location("lint_js", ROOT / "scripts/lint-js.py")
lint_js = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lint_js)
source = SOURCE.read_text(encoding="utf-8")
emitted = lint_js.literals_in(lint_js.function_body(source, "ADProbeWebJS")).replace("%%", "%")
start = emitted.index("function compareNative428(){")
end = emitted.index("try{window.__AD_COMPARE_NATIVE428__=", start)
function = emitted[start:end]

fixture = r'''
class Style {
  constructor(){this.values=new Map();}
  setProperty(key,value){this.values.set(key,String(value));}
  getPropertyValue(key){return this.values.get(key)||'';}
  removeProperty(key){const value=this.getPropertyValue(key);this.values.delete(key);return value;}
}
function attr(element,name){return name==='class'?element.className:element.attrs.get(name);}
function matchesOne(element,selector){
  selector=selector.trim();if(!selector)return false;
  const tag=selector.match(/^[A-Za-z][A-Za-z0-9_-]*/);
  if(tag&&element.tagName!==tag[0].toUpperCase())return false;
  for(const match of selector.matchAll(/\.([A-Za-z0-9_-]+)/g))
    if(!String(element.className||'').split(/\s+/).includes(match[1]))return false;
  const pattern=/\[([^\]\s=*]+)(?:([*]?=)(?:"([^"]*)"|'([^']*)'|([^\]]*)))?\]/g;
  for(const match of selector.matchAll(pattern)){
    const value=attr(element,match[1]);if(value===undefined)return false;
    if(match[2]){
      const wanted=match[3]??match[4]??match[5]??'',actual=String(value);
      if(match[2]==='='&&actual!==wanted)return false;
      if(match[2]==='*='&&!actual.includes(wanted))return false;
    }
  }
  return true;
}
function matchesAny(element,selector){return selector.split(',').some(item=>matchesOne(element,item));}
class Element {
  constructor(tag,attrs={}){
    this.tagName=tag.toUpperCase();this.nodeType=1;this.attrs=new Map();this.children=[];
    this.parentElement=null;this.parentNode=null;this.style=new Style();this.className='';
    this.textContent='';this.listeners={};this.rect={width:32,height:32,left:0,top:0,right:32,bottom:32};
    for(const [key,value] of Object.entries(attrs))this.setAttribute(key,value);
  }
  set id(value){this.setAttribute('id',value);} get id(){return this.getAttribute('id')||'';}
  setAttribute(key,value){this.attrs.set(key,String(value));if(key==='class')this.className=String(value);if(key==='type')this.type=String(value);}
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
  click(){if(this.tagName==='INPUT'&&String(this.type).toLowerCase()==='checkbox')this.checked=!this.checked;for(const handler of this.listeners.click||[])handler({target:this});}
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
function element(tag,attrs={}){return new Element(tag,attrs);}
function assert(value,message){if(!value)throw new Error(message);}

const card=element('div',{class:'puis-card','data-asin':'A1'});
const host=element('div',{'data-ad-stock403':'c'});
const input=element('input',{type:'checkbox'});
const icon=element('i',{class:'a-icon-checkbox'});
input.checked=false;host.__adManual380=1;host.__adManualSig380='stale';
host.appendChild(input);host.appendChild(icon);card.appendChild(host);document.body.appendChild(card);
let nativeCalls=0,pane=false;
input.addEventListener('click',()=>{nativeCalls++;pane=true;});
assert(compareNative428()===1,'input fixture host count');
assert(host.getAttribute('data-ad-comparefunc428')==='1','input host not marked');
assert(input.getAttribute('data-ad-comparehit428')==='input','real input is not the hit target');
assert(host.getAttribute('data-ad-compareselected428')==='0','stale manual state won');
assert(!('__adManual380' in host)&&!('__adManualSig380' in host),'manual emulation not cleared');

input.click();
assert(nativeCalls===1&&pane&&input.checked,'native handler/default did not survive');
compareNative428();
assert(host.getAttribute('data-ad-compareselected428')==='1','checked input not mirrored');
assert(host.style.getPropertyValue('background-color')==='#2162a1','selected blue fill missing');
assert(host.style.getPropertyValue('border-color')==='#2162a1','selected blue border missing');

input.click();compareNative428();
assert(host.getAttribute('data-ad-compareselected428')==='0','unchecked input not mirrored');
assert(host.style.getPropertyValue('background-color')===''&&host.style.getPropertyValue('border-color')==='','owned blue paint not released');

const legacyCard=element('div',{class:'s-result-item'});
const legacy=element('span',{'data-ad-comparelegacy387':'0'});
const stockIcon=element('i',{class:'a-icon-checkbox'});
legacy.appendChild(stockIcon);legacyCard.appendChild(legacy);document.body.appendChild(legacyCard);
assert(compareNative428()===2,'legacy stock-art host not found');
assert(stockIcon.getAttribute('data-ad-comparehit428')==='leaf','stock artwork not restored as native leaf target');

const currentCard=element('div',{class:'puis-card'});
const currentCompare=element('div',{class:'a-checkbox'});
const currentInput=element('input',{type:'checkbox'});currentInput.checked=false;
currentCompare.appendChild(currentInput);currentCard.appendChild(currentCompare);document.body.appendChild(currentCard);
assert(compareNative428()===3,'current a-checkbox host was skipped');
assert(currentCompare.hasAttribute('data-ad-comparefunc428')&&currentInput.getAttribute('data-ad-comparehit428')==='input','current native target not restored');

const mltCard=element('div',{class:'puis-card'});
const mlt=element('div',{class:'mlt-icon-container','data-ad-compare380':'0'});
const mltGlyph=element('i',{class:'a-icon-checkbox'});
mlt.appendChild(mltGlyph);mltCard.appendChild(mlt);document.body.appendChild(mltCard);
assert(compareNative428()===3,'MLT two-cards subtree entered');
assert(!mlt.hasAttribute('data-ad-comparefunc428')&&!mltGlyph.hasAttribute('data-ad-comparehit428'),'MLT two-cards control was touched');

const cardsCard=element('div',{class:'puis-card'});
const cards=element('div',{class:'lists-framework-action-button','data-ad-compare380':'0'});
const cardsGlyph=element('i',{class:'a-icon-checkbox'});
cards.appendChild(cardsGlyph);cardsCard.appendChild(cards);document.body.appendChild(cardsCard);
assert(compareNative428()===3,'two-cards subtree entered');
assert(!cards.hasAttribute('data-ad-comparefunc428')&&!cardsGlyph.hasAttribute('data-ad-comparehit428'),'two-cards control was touched');

const heartCard=element('div',{class:'puis-card'});
const heart=element('div',{class:'puis-heart-position','data-ad-compare380':'0'});
const heartGlyph=element('i',{class:'a-icon-checkbox'});
heart.appendChild(heartGlyph);heartCard.appendChild(heart);document.body.appendChild(heartCard);
assert(compareNative428()===3,'Heart subtree entered');
assert(!heart.hasAttribute('data-ad-comparefunc428')&&!heartGlyph.hasAttribute('data-ad-comparehit428'),'Heart control was touched');

const styles=document.head.querySelectorAll('[id="adcomparenative428"]');
assert(styles.length===1,'stylesheet duplicated');
const css=styles[0].textContent;
assert(css.includes('pointer-events:auto !important'),'native hit CSS missing');
assert(css.includes('background-color:#2162a1')&&css.includes('border:solid #fff'),'selected blue/check CSS missing');
assert(css.includes('::before{background:#2162a1'),'existing square painter is not pinned blue');
console.log('compare-native-428 fixture: PASS (native handler, selected blue/check, stock/current targets, MLT/cards/Heart exclusions)');
'''

result = subprocess.run([NODE, "-e", function + fixture], text=True, capture_output=True)
if result.stdout:
    print(result.stdout, end="")
if result.stderr:
    print(result.stderr, end="", file=sys.stderr)
raise SystemExit(result.returncode)

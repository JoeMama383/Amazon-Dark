#!/usr/bin/env python3
"""Exercise the v5.433 stock Compare checkbox against representative Amazon DOM."""
from pathlib import Path
import importlib.util
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "src/Tweak.xm"
NODE = shutil.which("node")

if not NODE:
    print("checkbox-stock-433 fixture: SKIP (node not installed)")
    raise SystemExit(0)

spec = importlib.util.spec_from_file_location("lint_js", ROOT / "scripts/lint-js.py")
lint_js = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lint_js)
source = SOURCE.read_text(encoding="utf-8")
emitted = lint_js.literals_in(lint_js.function_body(source, "ADProbeWebJS")).replace("%%", "%")
start = emitted.index("function stockCheckbox433(){")
end = emitted.index("try{window.__AD_CHECKBOX433__=", start)
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

const retiredStock=element('style',{id:'adstock403'});
const retiredNative=element('style',{id:'adcomparenative428'});
document.head.appendChild(retiredStock);document.head.appendChild(retiredNative);

const card=element('div',{class:'puis-card','data-asin':'A1'});
const host=element('div',{class:'a-checkbox','data-ad-sym413':'checkbox','data-ad-compare380':'0','data-ad-stock403':'c','data-ad-product391':'checkbox'});
const input=element('input',{type:'checkbox','data-ad-compareinput380':'1'});
const icon=element('i',{class:'a-icon a-icon-checkbox','data-ad-compareorig380':'1','data-ad-stockglyph403':'c'});
const synthetic=element('span',{'data-ad-comparebox377':'1'});
input.checked=false;host.__adManual380=1;host.__adManualSig380='stale';host.__adCompareBlue428=1;
host.style.setProperty('background-color','#181a1b');host.style.setProperty('border','1.5px solid white');
host.style.setProperty('border-radius','4px');host.style.setProperty('width','32px');
input.style.setProperty('opacity','0');input.style.setProperty('position','absolute');input.style.setProperty('width','100%');
icon.style.setProperty('filter','none');icon.style.setProperty('opacity','0');icon.style.setProperty('background-color','transparent');
icon.__adBy='disc422';
host.appendChild(input);host.appendChild(icon);host.appendChild(synthetic);card.appendChild(host);document.body.appendChild(card);

let nativeCalls=0,pane=false;
input.addEventListener('click',()=>{nativeCalls++;pane=true;});
assert(stockCheckbox433()===1,'stock checkbox host count');
assert(!document.getElementById('adstock403')&&!document.getElementById('adcomparenative428'),'retired stylesheet survived');
assert(!host.hasAttribute('data-ad-sym413')&&!host.hasAttribute('data-ad-compare380')&&!host.hasAttribute('data-ad-stock403')&&!host.hasAttribute('data-ad-product391'),'old host ownership survived');
for(const property of ['background-color','border','border-radius','width'])
  assert(host.style.getPropertyValue(property)==='',property+' host paint/geometry survived');
for(const property of ['opacity','position','width'])
  assert(input.style.getPropertyValue(property)==='',property+' input rewrite survived');
assert(!host.querySelector('[data-ad-comparebox377]'),'synthetic checkbox painter survived');
assert(icon.getAttribute('data-ad-checkbox433-art')==='unchecked','unchecked stock artwork not marked');
assert(icon.style.getPropertyValue('filter')===''&&icon.style.getPropertyValue('opacity')===''&&icon.style.getPropertyValue('background-color')==='','old artwork paint survived');
assert(!host.hasAttribute('data-ad-checkbox433-art')&&!input.hasAttribute('data-ad-checkbox433-art'),'filter marker escaped stock artwork');

input.click();
assert(nativeCalls===1&&pane&&input.checked,'native Amazon handler/default did not survive');
stockCheckbox433();
assert(icon.getAttribute('data-ad-checkbox433-art')==='checked','checked stock sprite not released');

input.click();stockCheckbox433();
assert(nativeCalls===2&&!input.checked&&icon.getAttribute('data-ad-checkbox433-art')==='unchecked','native uncheck did not restore inversion marker');

const css=document.getElementById('adcheckbox433').textContent;
assert(css==='[data-ad-checkbox433-art="unchecked"]{filter:invert(1) !important;}[data-ad-checkbox433-art="checked"]{filter:none !important;}','stylesheet is not the exact two-filter contract');
assert(!/(background|border|radius|shadow|width|height|position|transform|opacity|visibility|content|display|pointer-events)\s*:/i.test(css),'stylesheet paints or resizes');
assert((css.match(/filter:/g)||[]).length===2,'unexpected checkbox declarations');
assert(document.head.querySelectorAll('[id="adcheckbox433"]').length===1,'stylesheet duplicated');

function excluded(rootClass){
  const outer=element('div',{class:'puis-card'}),root=element('div',{class:rootClass});
  const box=element('div',{class:'a-checkbox'}),q=element('input',{type:'checkbox'}),art=element('i',{class:'a-icon-checkbox'});
  q.checked=false;box.appendChild(q);box.appendChild(art);root.appendChild(box);outer.appendChild(root);document.body.appendChild(outer);
  return {box,art};
}
const excludedControls=[excluded('mlt-icon-container'),excluded('lists-framework-action-button'),excluded('puis-heart-position'),excluded('puis-mab-chevron')];
assert(stockCheckbox433()===1,'excluded icon family counted as Compare');
for(const item of excludedControls){
  assert(!item.art.hasAttribute('data-ad-checkbox433-art'),'filter leaked into another icon');
  assert(!item.box.hasAttribute('data-ad-checkbox433-art'),'marker leaked into another icon host');
}

const unrelated=element('i',{class:'a-icon-heart'});
unrelated.style.setProperty('filter','heart-lock');document.body.appendChild(unrelated);stockCheckbox433();
assert(unrelated.style.getPropertyValue('filter')==='heart-lock','unrelated icon changed');

console.log('checkbox-stock-433 fixture: PASS (native click, cleanup, unchecked-only inversion, stock blue sprite, icon exclusions)');
'''

result = subprocess.run([NODE, "-e", function + fixture], text=True, capture_output=True)
if result.stdout:
    print(result.stdout, end="")
if result.stderr:
    print(result.stderr, end="", file=sys.stderr)
raise SystemExit(result.returncode)

#!/usr/bin/env python3
"""Lock v5.447's Compare-minus and Home-native-creative paint boundaries."""

from pathlib import Path
import importlib.util
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "src/Tweak.xm"
NODE = shutil.which("node")

if not NODE:
    print("theme-surfaces-447 fixture: SKIP (node not installed)")
    raise SystemExit(0)

spec = importlib.util.spec_from_file_location("lint_js", ROOT / "scripts/lint-js.py")
lint_js = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lint_js)
source = SOURCE.read_text(encoding="utf-8")
fixes = lint_js.literals_in(lint_js.function_body(source, "ADFixesLiteral")).replace("%%", "%")
emitted = lint_js.literals_in(lint_js.function_body(source, "ADProbeWebJS")).replace("%%", "%")

compare_start = emitted.index("function comparePane447(){")
home_start = emitted.index("function homeCreative447(){", compare_start)
ambient_start = emitted.index("function homeAmbient386(){", home_start)
compare_function = emitted[compare_start:home_start]
home_function = emitted[home_start:ambient_start]

required_first_paint = [
    "[class*=single-creative-card] [class*=theming-card-background]:not([data-ad-homecreative447])",
    "[class*=single-video-card] [class*=theming-card-background]",
    "[class*=theming-card] [class*=theming-card-background]:not([data-ad-homecreative447])",
]
missing = [token for token in required_first_paint if token not in source]
if missing:
    print("theme-surfaces-447 fixture: FAIL (creative release/video guard missing: " + ", ".join(missing) + ")")
    raise SystemExit(1)

for required in [
    "compare with similar|keep selecting",
    "data-ad-compareminus447-host",
    "data-ad-compareminus447-glyph",
    "data-ad-compareminus447-before",
    "data-ad-compareminus447-after",
    "data-ad-compareminus447-hostbg",
    "data-ad-compareminus447-hostrad",
    "[data-ad-compareminus447-glyph=solid]{background-color:#e8e6e3 !important;}",
    "[data-ad-compareminus447-glyph=raster]{filter:brightness(0) invert(1) !important;}",
]:
    if required not in compare_function:
        print("theme-surfaces-447 fixture: FAIL (Compare-minus contract missing: " + required + ")")
        raise SystemExit(1)

if "host447.style" in compare_function:
    print("theme-surfaces-447 fixture: FAIL (minus repair writes the circular host)")
    raise SystemExit(1)
for forbidden in [".click(", "dispatchEvent", "preventDefault(", "stopPropagation(", "createElement('svg')", "innerHTML=", "outerHTML="]:
    if forbidden in compare_function:
        print("theme-surfaces-447 fixture: FAIL (minus repair changes interaction/artwork: " + forbidden + ")")
        raise SystemExit(1)
for required in [
    "[class*=single-creative-card] [class*=theming-card-background]",
    "setAttribute('data-ad-homecreative447','native')",
    "r447.width<100||r447.height<100",
]:
    if required not in home_function:
        print("theme-surfaces-447 fixture: FAIL (Home creative contract missing: " + required + ")")
        raise SystemExit(1)
if ".style." in home_function or "single-video-card" in home_function:
    print("theme-surfaces-447 fixture: FAIL (Home release writes color or claims video)")
    raise SystemExit(1)

fixture = r'''
class Style {
  constructor(){this.values=new Map();}
  setProperty(key,value){this.values.set(String(key),String(value));}
  getPropertyValue(key){return this.values.get(String(key))||'';}
  removeProperty(key){const value=this.getPropertyValue(key);this.values.delete(String(key));return value;}
}
function attr(element,name){return name==='class'?element.className:element.attrs.get(name);}
function simpleMatch(element,selector){
  selector=selector.trim();if(!selector)return false;if(selector==='*')return true;
  const id=selector.match(/#([A-Za-z0-9_-]+)/);if(id&&element.id!==id[1])return false;
  const tag=selector.match(/^[A-Za-z][A-Za-z0-9_-]*/);if(tag&&element.tagName!==tag[0].toUpperCase())return false;
  for(const match of selector.matchAll(/\.([A-Za-z0-9_-]+)/g))if(!String(element.className||'').split(/\s+/).includes(match[1]))return false;
  const pattern=/\[([^\]\s~*="']+)(?:([~*]?=)(?:"([^"]*)"|'([^']*)'|([^\]]*)))?\]/g;
  for(const match of selector.matchAll(pattern)){
    const value=attr(element,match[1]);if(value===undefined)return false;
    if(match[2]){const wanted=match[3]??match[4]??match[5]??'',actual=String(value);
      if(match[2]==='='&&actual!==wanted)return false;if(match[2]==='*='&&!actual.includes(wanted))return false;if(match[2]==='~='&&!actual.split(/\s+/).includes(wanted))return false;}
  }
  return true;
}
function matchesSelector(element,selector){
  const parts=selector.trim().split(/\s+/);const leaf=parts.pop();if(!simpleMatch(element,leaf))return false;
  let node=element.parentElement;while(parts.length){const wanted=parts.pop();while(node&&!simpleMatch(node,wanted))node=node.parentElement;if(!node)return false;node=node.parentElement;}return true;
}
function matchesAny(element,selectors){return selectors.split(',').some(selector=>matchesSelector(element,selector));}
class Element {
  constructor(tag,attrs={},rect={left:0,top:0,width:32,height:32}){
    this.tagName=tag.toUpperCase();this.nodeType=1;this.attrs=new Map();this.children=[];this.parentElement=null;this.parentNode=null;
    this.style=new Style();this.className='';this.textContent='';this.innerText='';this.rect={...rect,right:rect.left+rect.width,bottom:rect.top+rect.height};
    this.computed={backgroundColor:'transparent',backgroundImage:'none',maskImage:'none',webkitMaskImage:'none',borderRadius:'0px',borderTopLeftRadius:'0px',color:'rgb(15,17,17)',fill:'rgb(0,0,0)',stroke:'rgb(0,0,0)',filter:'none'};
    this.before={content:'none',width:'0px',height:'0px',backgroundColor:'transparent',backgroundImage:'none',maskImage:'none',webkitMaskImage:'none',color:'rgb(15,17,17)',filter:'none'};
    this.after={...this.before};for(const [key,value] of Object.entries(attrs))this.setAttribute(key,value);
  }
  set id(value){this.setAttribute('id',value);}get id(){return this.getAttribute('id')||'';}
  setAttribute(key,value){this.attrs.set(key,String(value));if(key==='class')this.className=String(value);}
  getAttribute(key){const value=attr(this,key);return value===undefined?null:value;}
  hasAttribute(key){return key==='class'?!!this.className:this.attrs.has(key);}
  removeAttribute(key){this.attrs.delete(key);if(key==='class')this.className='';}
  appendChild(child){child.parentElement=this;child.parentNode=this;this.children.push(child);return child;}
  removeChild(child){const i=this.children.indexOf(child);if(i>=0)this.children.splice(i,1);child.parentElement=child.parentNode=null;return child;}
  getBoundingClientRect(){return this.rect;}
  matches(selector){return matchesAny(this,selector);}
  closest(selector){for(let node=this;node;node=node.parentElement)if(matchesAny(node,selector))return node;return null;}
  contains(target){for(let node=target;node;node=node.parentElement)if(node===this)return true;return false;}
  querySelectorAll(selector){const out=[];for(const child of this.children){if(matchesAny(child,selector))out.push(child);out.push(...child.querySelectorAll(selector));}return out;}
  querySelector(selector){return this.querySelectorAll(selector)[0]||null;}
}
class Document {
  constructor(){this.documentElement=new Element('html');this.head=new Element('head');this.body=new Element('body');this.documentElement.appendChild(this.head);this.documentElement.appendChild(this.body);}
  createElement(tag){return new Element(tag);}
  querySelectorAll(selector){const out=[];for(const root of [this.head,this.body]){if(matchesAny(root,selector))out.push(root);out.push(...root.querySelectorAll(selector));}return out;}
  querySelector(selector){return this.querySelectorAll(selector)[0]||null;}
  getElementById(id){return this.querySelector('#'+id);}
}
function computedFor(element,pseudo){
  const base=pseudo==='::before'?{...element.before}:pseudo==='::after'?{...element.after}:{...element.computed};
  if(!pseudo&&element.hasAttribute('data-ad-compareminus447-glyph')){
    const kind=element.getAttribute('data-ad-compareminus447-glyph');base.color='rgb(232,230,227)';base.fill='rgb(232,230,227)';base.stroke='rgb(232,230,227)';
    if(kind==='solid')base.backgroundColor='rgb(232,230,227)';if(kind==='raster')base.filter='brightness(0) invert(1)';
  }
  if(pseudo==='::before'&&element.hasAttribute('data-ad-compareminus447-before')){const kind=element.getAttribute('data-ad-compareminus447-before');if(kind==='solid')base.backgroundColor='rgb(232,230,227)';if(kind==='raster')base.filter='brightness(0) invert(1)';if(kind==='text')base.color='rgb(232,230,227)';}
  if(pseudo==='::after'&&element.hasAttribute('data-ad-compareminus447-after')){const kind=element.getAttribute('data-ad-compareminus447-after');if(kind==='solid')base.backgroundColor='rgb(232,230,227)';if(kind==='raster')base.filter='brightness(0) invert(1)';if(kind==='text')base.color='rgb(232,230,227)';}
  if(!pseudo&&String(element.className).includes('theming-card-background'))base.backgroundColor=element.hasAttribute('data-ad-homecreative447')?(element.nativeBackground||'rgb(8,31,58)'):'rgb(24,26,27)';
  base.getPropertyValue=key=>element.style.getPropertyValue(key);return base;
}
global.window=global;global.NodeFilter=undefined;global.__ADFRAME_MODE__=false;global.getComputedStyle=computedFor;
function el(tag,attrs,left,top,width,height){return new Element(tag,attrs,{left,top,width,height});}
function assert(value,message){if(!value)throw new Error(message);}
function fresh(){global.document=new Document();return document;}

// Real screenshot shape: a 52px thumbnail, an overlapping 32px dark circle,
// and a nested 12x3 dark bar. Only the bar may change paint.
fresh();document.body.innerText='Compare with similar or keep selecting';document.body.textContent=document.body.innerText;
const tray=el('div',{class:'compare-selection-tray'},0,700,390,92);tray.textContent=document.body.innerText;
const thumb=el('img',{class:'selection-thumbnail'},20,718,52,52);
const host=el('button',{class:'selection-remove-badge','aria-label':'Remove selected item'},62,728,32,32);host.computed.backgroundColor='rgb(24,26,27)';host.computed.borderRadius='16px';host.computed.borderTopLeftRadius='16px';
const minus=el('span',{class:'selection-minus'},72,742,12,3);minus.computed.backgroundColor='rgb(10,10,10)';
const close=el('button',{class:'selection-close'},320,728,32,32);close.computed.backgroundColor='rgb(24,26,27)';close.computed.borderRadius='16px';close.computed.borderTopLeftRadius='16px';
host.appendChild(minus);tray.appendChild(thumb);tray.appendChild(host);tray.appendChild(close);document.body.appendChild(tray);
const beforeHostBg=getComputedStyle(host).backgroundColor,beforeHostRadius=getComputedStyle(host).borderRadius;
assert(comparePane447()===1,'nested-minus tray was not discovered: '+String(global.__AD_COMPAREPANE447_STATE__));
assert(host.getAttribute('data-ad-compareminus447-host')==='1'&&minus.getAttribute('data-ad-compareminus447-glyph')==='solid','minus ownership landed on the wrong node');
assert(getComputedStyle(minus).backgroundColor==='rgb(232,230,227)','nested minus did not become light');
assert(getComputedStyle(host).backgroundColor===beforeHostBg&&getComputedStyle(host).borderRadius===beforeHostRadius,'dark circular host changed');
assert(!close.hasAttribute('data-ad-compareminus447-host'),'far close button was mistaken for selected-item minus');
assert([...host.style.values.keys()].length===0,'minus repair wrote inline style to its host');

// Amazon may draw the bar as a host pseudo. The paint boundary remains identical.
fresh();document.body.innerText='Compare with similar or keep selecting';document.body.textContent=document.body.innerText;
const pseudoTray=el('section',{class:'compare-selection-tray'},0,700,390,92);pseudoTray.textContent=document.body.innerText;
const pseudoThumb=el('img',{class:'selection-thumbnail'},20,718,52,52);
const pseudoHost=el('span',{class:'selection-remove-badge'},62,728,32,32);pseudoHost.computed.backgroundColor='rgb(24,26,27)';pseudoHost.computed.borderRadius='16px';pseudoHost.computed.borderTopLeftRadius='16px';pseudoHost.before={content:'none',width:'12px',height:'3px',backgroundColor:'rgb(8,8,8)',backgroundImage:'none',maskImage:'none',webkitMaskImage:'none',color:'rgb(8,8,8)',filter:'none'};
pseudoTray.appendChild(pseudoThumb);pseudoTray.appendChild(pseudoHost);document.body.appendChild(pseudoTray);
assert(comparePane447()===1&&pseudoHost.getAttribute('data-ad-compareminus447-before')==='solid','pseudo-minus tray was not discovered');
assert(getComputedStyle(pseudoHost,'::before').backgroundColor==='rgb(232,230,227)','pseudo minus did not become light');
assert(getComputedStyle(pseudoHost).backgroundColor==='rgb(24,26,27)'&&getComputedStyle(pseudoHost).borderRadius==='16px','pseudo-minus host changed');

// The old first-paint black rule is released only for real Home creative leaves.
fresh();document.body.innerText='Amazon Home';document.body.textContent=document.body.innerText;
const creative=el('article',{class:'single-creative-card'},20,180,300,470),leaf=el('div',{class:'theming-card-background'},20,180,300,470);leaf.nativeBackground='rgb(8,31,58)';creative.appendChild(leaf);document.body.appendChild(creative);
const video=el('article',{class:'single-video-card'},330,180,300,470),videoLeaf=el('div',{class:'theming-card-background'},330,180,300,470);videoLeaf.nativeBackground='rgb(84,24,16)';video.appendChild(videoLeaf);document.body.appendChild(video);
assert(getComputedStyle(leaf).backgroundColor==='rgb(24,26,27)','fixture did not model old forced-black creative');
assert(homeCreative447()===1,'Home creative leaf was not tagged: '+String(global.__AD_HOMECREATIVE447_STATE__));
assert(leaf.getAttribute('data-ad-homecreative447')==='native'&&getComputedStyle(leaf).backgroundColor==='rgb(8,31,58)','native navy creative did not return');
assert(!videoLeaf.hasAttribute('data-ad-homecreative447')&&getComputedStyle(videoLeaf).backgroundColor==='rgb(24,26,27)','video guard was released with the creative');
assert([...leaf.style.values.keys()].length===0,'Home release replaced Amazon native color inline');

console.log('theme-surfaces-447 fixture: PASS (minus light only; host unchanged; native navy creative restored; video guard retained)');
'''

result = subprocess.run([NODE, "-e", compare_function + home_function + fixture], text=True, capture_output=True)
if result.stdout:
    print(result.stdout, end="")
if result.stderr:
    print(result.stderr, end="", file=sys.stderr)
raise SystemExit(result.returncode)

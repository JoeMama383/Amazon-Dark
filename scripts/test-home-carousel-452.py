#!/usr/bin/env python3
"""Lock v5.452's authored Home carousel color and uniform tame overlay."""

from pathlib import Path
import importlib.util
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "src/Tweak.xm"
NODE = shutil.which("node")

if not NODE:
    print("home-carousel-452 fixture: SKIP (node not installed)")
    raise SystemExit(0)

source = SOURCE.read_text(encoding="utf-8")
spec = importlib.util.spec_from_file_location("lint_js", ROOT / "scripts/lint-js.py")
lint_js = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lint_js)

bootstrap = lint_js.literals_in(
    lint_js.function_body(source, "ADDarkReaderBootstrapBuild")
).replace("%%", "%")
runtime = lint_js.literals_in(
    lint_js.function_body(source, "ADProbeWebJS")
).replace("%%", "%")

capture_start = bootstrap.index("try{if(window===window.top&&!window.__AD_HOMECAP452__)")
capture_end = bootstrap.index("try{if(document&&!document.getElementById('adcardfix'))", capture_start)
capture = bootstrap[capture_start:capture_end]

owner_start = runtime.index("function _adHomeApply452")
owner_end = runtime.index("homeAmbient386();badgeFix()", owner_start)
owner = runtime[owner_start:owner_end]

required = [
    "data-ad-homecolor452",
    "__adHomeAuth452",
    "backgroundPriority",
    "imagePriority",
    "single-video-card|video-card|video-js|vjs-|sbv-video",
    "{childList:true,subtree:true}",
    ":not([data-ad-homecreative448]):not([data-ad-homecolor452])",
    "function _adHomeApply452",
    "linear-gradient(",
    "0.50*(S452/100)",
    "data-ad-homeoverlay452",
    "homeColorOverlay452",
    "[data-ad-homecolor452=\"authored\"]",
    "captured='+E452.length+' tamed='+n452+' missing='+miss452",
    "P95HOME452[captured=",
]
missing = [token for token in required if token not in capture + owner + bootstrap + runtime]
if missing:
    print("home-carousel-452 fixture: FAIL (contract missing: " + ", ".join(missing) + ")")
    raise SystemExit(1)

for forbidden in [
    "if(r452.width", "if(r452.height", "Math.max(q452",
    ".click(", "dispatchEvent", "preventDefault(", "stopPropagation(",
    "createElement('svg')", "innerHTML=", "outerHTML=",
]:
    if forbidden in owner:
        print("home-carousel-452 fixture: FAIL (owner broadened or stateful: " + forbidden + ")")
        raise SystemExit(1)

prelude = r'''
class Style {
  constructor(){this.values=new Map();this.priorities=new Map();}
  setProperty(k,v,p=''){this.values.set(String(k),String(v));this.priorities.set(String(k),String(p));}
  getPropertyValue(k){return this.values.get(String(k))||'';}
  getPropertyPriority(k){return this.priorities.get(String(k))||'';}
  removeProperty(k){const old=this.getPropertyValue(k);this.values.delete(String(k));this.priorities.delete(String(k));return old;}
}
class Element {
  constructor(tag,cls,w,h){this.nodeType=1;this.tagName=tag.toUpperCase();this.className=cls;this.rect={left:0,top:0,width:w,height:h,right:w,bottom:h};this.attrs=new Map();this.style=new Style();this.parentElement=null;this.children=[];}
  getBoundingClientRect(){return this.rect;}
  setAttribute(k,v){this.attrs.set(String(k),String(v));}
  getAttribute(k){return this.attrs.has(String(k))?this.attrs.get(String(k)):null;}
  hasAttribute(k){return this.attrs.has(String(k));}
  removeAttribute(k){this.attrs.delete(String(k));}
  querySelectorAll(selector){return selector==='[class*=theming-card-background]'?this.children.filter(e=>String(e.className).includes('theming-card-background')):[];}
}
const creativeParent=new Element('div','single-creative-card carousel-card',299,478);
const blue=new Element('div','theming-card-background',299,478);blue.parentElement=creativeParent;blue.style.setProperty('background-color','rgb(0, 124, 220)','important');
const orange=new Element('div','theming-card-background',299,478);orange.parentElement=creativeParent;orange.style.setProperty('background-color','rgb(255, 90, 0)','important');orange.style.setProperty('background-image','url("authored-orange.png")','important');
const transparent=new Element('div','theming-card-background',120,90);transparent.parentElement=creativeParent;transparent.style.setProperty('background-color','rgba(0, 0, 0, 0)','important');
const videoParent=new Element('div','single-video-card video-js',299,478);
const video=new Element('div','theming-card-background',299,478);video.parentElement=videoParent;video.style.setProperty('background-color','rgb(220, 30, 30)','important');
const unrelated=new Element('div','ordinary-card-background',299,478);unrelated.parentElement=creativeParent;unrelated.style.setProperty('background-color','rgb(20, 180, 40)','important');
const creativeImage=new Element('img','_single-creative-card_style_image__x',299,478);creativeImage.style.setProperty('filter','brightness(0.775) saturate(1.08)','important');
const cards=[blue,orange,transparent,video,unrelated];
const root=new Element('html','',390,844);root.children=cards;
global.window=global;window.top=window;window.__ADFRAME_MODE__=false;window.__ADTAME_ON__=true;window.__ADTAME_S__=45;
global.location={pathname:'/'};
global.MutationObserver=class {constructor(cb){this.cb=cb;}observe(){}disconnect(){}};
global.setTimeout=()=>1;global.clearTimeout=()=>{};global.addEventListener=()=>{};
global.document={body:{},documentElement:root,querySelector(){return null;},querySelectorAll(selector){
  if(selector==='[data-ad-homecolor452="authored"]')return cards.filter(e=>e.getAttribute('data-ad-homecolor452')==='authored');
  if(selector==='[class*=theming-card-background]')return cards.filter(e=>String(e.className).includes('theming-card-background'));
  return [];
}};
global.getComputedStyle=e=>({
  backgroundColor:e.style.getPropertyValue('background-color')||'rgba(0, 0, 0, 0)',
  backgroundImage:e.style.getPropertyValue('background-image')||'none',
  backgroundBlendMode:e.style.getPropertyValue('background-blend-mode')||'normal',
  boxShadow:e.style.getPropertyValue('box-shadow')||'none',
  filter:e.style.getPropertyValue('filter')||'none'
});
let legacyCalls=0;
function _adHomeBgLeaf395(){legacyCalls++;return true;}
function assert(ok,message){if(!ok)throw new Error(message);}
'''

damage = r'''
for(const e of [blue,orange,transparent]){
  e.style.setProperty('background-color','#181a1b','important');
  e.style.setProperty('background-image','none','important');
  e.style.setProperty('box-shadow','inset 0 0 0 9999px rgba(0,0,0,.225)','important');
  e.setAttribute('data-ad-homebg395','1');e.__adBy='homeBgLeaf395';
}
'''

assertions = r'''
assert(blue.getAttribute('data-ad-homecolor452')==='authored','blue card was not captured');
assert(orange.getAttribute('data-ad-homecolor452')==='authored','orange card was not captured');
assert(transparent.getAttribute('data-ad-homecolor452')==='authored','small/transparent carousel background was skipped');
assert(!video.hasAttribute('data-ad-homecolor452'),'video background entered authored-color owner');
assert(!unrelated.hasAttribute('data-ad-homecolor452'),'unrelated element entered authored-color owner');
assert(blue.style.getPropertyValue('background-color')==='rgb(0, 124, 220)','blue authored color was not restored');
assert(orange.style.getPropertyValue('background-color')==='rgb(255, 90, 0)','orange authored color was not restored');
assert(blue.style.getPropertyValue('background-image').startsWith('linear-gradient(rgba(0,0,0,0.225)'), 'blue card lacks uniform overlay');
assert(orange.style.getPropertyValue('background-image').includes('url("authored-orange.png")'),'authored background image was not preserved under overlay');
assert(transparent.style.getPropertyValue('background-image').includes('linear-gradient'),'transparent carousel background was not tamed');
assert([blue,orange,transparent].every(e=>e.getAttribute('data-ad-homeoverlay452')==='0.225'),'overlay strength is not uniform');
assert([blue,orange,transparent].every(e=>!e.hasAttribute('data-ad-homebg395')),'legacy black compositor ownership survived');
assert(creativeImage.style.getPropertyValue('filter')==='brightness(0.775) saturate(1.08)','child creative image WBT changed');
assert(video.style.getPropertyValue('background-color')==='rgb(220, 30, 30)'&&video.style.getPropertyValue('background-image')==='','video paint changed');
assert(_adHomeBgLeaf395(blue)===true,'captured card was not handled by v5.452 wrapper');
assert((blue.style.getPropertyValue('background-image').match(/linear-gradient/g)||[]).length===1,'reapply stacked duplicate overlays');
assert(_adHomeBgLeaf395(video)===true&&legacyCalls===1,'video no longer reaches v5.450 owner');
assert(/captured=3 tamed=3 missing=0/.test(window.__AD_HOMECOLOR452_STATE__),'state lacks complete coverage proof: '+window.__AD_HOMECOLOR452_STATE__);
console.log('home-carousel-452 fixture: PASS (authored colors restored; every non-video background uniformly tamed; child media unchanged)');
'''

result = subprocess.run(
    [NODE, "-e", prelude + capture + damage + owner + assertions],
    text=True,
    capture_output=True,
)
if result.stdout:
    print(result.stdout, end="")
if result.stderr:
    print(result.stderr, end="", file=sys.stderr)
raise SystemExit(result.returncode)

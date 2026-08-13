#!/usr/bin/env python3
"""Lock v5.453's late-authored Home color plus one uniform overlay."""

from pathlib import Path
import importlib.util
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "src/Tweak.xm"
NODE = shutil.which("node")

if not NODE:
    print("home-carousel-453 fixture: SKIP (node not installed)")
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

owner_start = runtime.index("function _adHomeOwnGradient453")
owner_end = runtime.index("homeAmbient386();badgeFix()", owner_start)
owner = runtime[owner_start:owner_end]
guard_start = bootstrap.index("try{if(!window.__AD_HOMEBG453_EARLY__")
guard_end = bootstrap.index("try{_adHomeMedia395();", guard_start)
early_guard = bootstrap[guard_start:guard_end]

required = [
    "data-ad-homecolor452",
    "__adHomeAuth452",
    ":not([data-ad-homecreative448]):not([data-ad-homecolor452])",
    "__AD_HOMEBG453_EARLY__",
    "__AD_HOMEBG395_RAW453__",
    "function _adHomeOwnGradient453",
    "function _adHomePaintSig453",
    "function _adHomeApply453",
    "external453=!a453.paintSig453||curSig453!==a453.paintSig453",
    "if(!ownImage453&&!legacy453)",
    "if(a453.color)s453.setProperty('background-color',a453.color,'important')",
    "s453.removeProperty('background-image')",
    "linear-gradient(",
    "0.50*(S453/100)",
    "data-ad-homeoverlay453",
    "homeColorOverlay453",
    "P96HOME453[captured=",
]
missing = [token for token in required if token not in capture + early_guard + owner + bootstrap + runtime]
if missing:
    print("home-carousel-453 fixture: FAIL (contract missing: " + ", ".join(missing) + ")")
    raise SystemExit(1)

for forbidden in [
    "put453('background'",
    "put453('background-color'",
    "resolvedImage===undefined",
    "if(r453.width",
    "if(r453.height",
    ".click(",
    "dispatchEvent",
    "preventDefault(",
    "stopPropagation(",
    "createElement('svg')",
    "innerHTML=",
    "outerHTML=",
]:
    if forbidden in owner:
        print("home-carousel-453 fixture: FAIL (owner broadened or regressed: " + forbidden + ")")
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
  constructor(tag,cls,w,h){this.nodeType=1;this.tagName=tag.toUpperCase();this.className=cls;this.rect={left:0,top:0,width:w,height:h,right:w,bottom:h};this.attrs=new Map();this.style=new Style();this.parentElement=null;this.children=[];this.cssColor='';this.cssImage='';}
  getBoundingClientRect(){return this.rect;}
  setAttribute(k,v){this.attrs.set(String(k),String(v));}
  getAttribute(k){return this.attrs.has(String(k))?this.attrs.get(String(k)):null;}
  hasAttribute(k){return this.attrs.has(String(k));}
  removeAttribute(k){this.attrs.delete(String(k));}
  querySelectorAll(selector){return selector==='[class*=theming-card-background]'?this.children.filter(e=>String(e.className).includes('theming-card-background')):[];}
}
const creativeParent=new Element('div','single-creative-card carousel-card',299,478);
const earlyBlue=new Element('div','theming-card-background',299,478);earlyBlue.parentElement=creativeParent;earlyBlue.style.setProperty('background-color','rgb(0, 124, 220)','important');
const lateNavy=new Element('div','theming-card-background',299,478);lateNavy.parentElement=creativeParent;
const orange=new Element('div','theming-card-background',299,478);orange.parentElement=creativeParent;orange.style.setProperty('background-color','rgb(255, 90, 0)');orange.style.setProperty('background-image','url("authored-orange.png")');
const transparent=new Element('div','theming-card-background',120,90);transparent.parentElement=creativeParent;transparent.style.setProperty('background-color','rgba(0, 0, 0, 0)');
const cssCard=new Element('div','theming-card-background',180,240);cssCard.parentElement=creativeParent;cssCard.cssColor='rgb(0, 92, 146)';cssCard.cssImage='url("class-authored.png")';
const videoParent=new Element('div','single-video-card video-js',299,478);
const video=new Element('div','theming-card-background',299,478);video.parentElement=videoParent;video.style.setProperty('background-color','rgb(220, 30, 30)');
const unrelated=new Element('div','ordinary-card-background',299,478);unrelated.parentElement=creativeParent;unrelated.style.setProperty('background-color','rgb(20, 180, 40)');
const creativeImage=new Element('img','_single-creative-card_style_image__x',299,478);creativeImage.style.setProperty('filter','brightness(0.775) saturate(1.08)','important');
const cards=[earlyBlue,lateNavy,orange,transparent,cssCard,video,unrelated];
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
  backgroundColor:e.style.getPropertyValue('background-color')||e.cssColor||'rgba(0, 0, 0, 0)',
  backgroundImage:e.style.getPropertyValue('background-image')||e.cssImage||'none',
  backgroundBlendMode:e.style.getPropertyValue('background-blend-mode')||'normal',
  boxShadow:e.style.getPropertyValue('box-shadow')||'none',
  filter:e.style.getPropertyValue('filter')||'none'
});
let legacyCalls=0;
function _adHomeBgLeaf395(){legacyCalls++;return true;}
function assert(ok,message){if(!ok)throw new Error(message);}
'''

after_capture = r'''
assert(lateNavy.__adHomeAuth452.color==='', 'late card did not reproduce the empty documentStart snapshot');
lateNavy.style.setProperty('background-color','rgb(0, 70, 125)');
lateNavy.style.setProperty('background-image','url("late-navy.png")');
assert(_adHomeBgLeaf395(lateNavy)===true,'early guard did not claim the late-painted Home backing');
assert(lateNavy.style.getPropertyValue('background-color')==='rgb(0, 70, 125)','old v5.395 compositor erased late navy before the final owner');
assert(lateNavy.style.getPropertyValue('background-image')==='url("late-navy.png")','old v5.395 compositor erased the late image before the final owner');
assert(lateNavy.__adHomeAuth452.color==='rgb(0, 70, 125)'&&lateNavy.__adHomeAuth452.image==='url("late-navy.png")','early guard did not record the late Amazon paint');
assert(lateNavy.style.getPropertyValue('box-shadow').includes('9999px rgba(0,0,0,0.225)'),'early guard traded the uniform overlay for color preservation');
assert(legacyCalls===0,'early guard delegated a claimed Home backing to v5.395');
for(const e of [earlyBlue,orange]){
  e.style.setProperty('background-color','#181a1b','important');
  e.style.setProperty('background-image','none','important');
  e.style.setProperty('box-shadow','inset 0 0 0 9999px rgba(0,0,0,.225)','important');
  e.setAttribute('data-ad-homebg395','1');e.__adBy='homeBgLeaf395';
}
'''

assertions = r'''
assert(earlyBlue.getAttribute('data-ad-homecolor452')==='authored','early blue card was not captured');
assert(lateNavy.getAttribute('data-ad-homecolor452')==='authored','late navy card was not captured');
assert(orange.getAttribute('data-ad-homecolor452')==='authored','orange card was not captured');
assert(transparent.getAttribute('data-ad-homecolor452')==='authored','small transparent background was skipped');
assert(cssCard.getAttribute('data-ad-homecolor452')==='authored','class-painted background was skipped');
assert(!video.hasAttribute('data-ad-homecolor452'),'video background entered the Home color owner');
assert(!unrelated.hasAttribute('data-ad-homecolor452'),'unrelated element entered the Home color owner');
assert(earlyBlue.style.getPropertyValue('background-color')==='rgb(0, 124, 220)','pre-captured blue was not restored after legacy damage');
assert(lateNavy.style.getPropertyValue('background-color')==='rgb(0, 70, 125)','late navy declaration was erased by the empty snapshot');
assert(lateNavy.style.getPropertyPriority('background-color')==='important','late authored color was not made authoritative');
assert(orange.style.getPropertyValue('background-color')==='rgb(255, 90, 0)','orange authored color was not restored');
assert(orange.style.getPropertyValue('background-image').includes('url("authored-orange.png")'),'legacy damage replaced the captured authored image');
assert(lateNavy.style.getPropertyValue('background-image').includes('url("late-navy.png")'),'late authored background image was not preserved');
assert(cssCard.style.getPropertyValue('background-image').includes('url("class-authored.png")'),'class-authored background image was not preserved');
assert(getComputedStyle(cssCard).backgroundColor==='rgb(0, 92, 146)','class-authored background color was replaced');
assert([earlyBlue,lateNavy,orange,transparent,cssCard].every(e=>e.getAttribute('data-ad-homeoverlay453')==='0.225'),'overlay strength is not uniform');
assert([earlyBlue,lateNavy,orange,transparent,cssCard].every(e=>(e.style.getPropertyValue('background-image').match(/linear-gradient/g)||[]).length===1),'a card is missing its single overlay or has stacked overlays');
assert([earlyBlue,orange].every(e=>!e.hasAttribute('data-ad-homebg395')),'legacy black compositor ownership survived');
assert(creativeImage.style.getPropertyValue('filter')==='brightness(0.775) saturate(1.08)','child creative image WBT changed');
assert(video.style.getPropertyValue('background-color')==='rgb(220, 30, 30)'&&video.style.getPropertyValue('background-image')==='','video paint changed');
assert(_adHomeBgLeaf395(lateNavy)===true&&legacyCalls===0,'captured card escaped the v5.453 wrapper');
assert(_adHomeBgLeaf395(video)===true&&legacyCalls===1,'unclaimed video no longer reaches the frozen v5.395 owner');
assert((lateNavy.style.getPropertyValue('background-image').match(/linear-gradient/g)||[]).length===1,'ordinary reapply stacked an overlay');

lateNavy.style.setProperty('background-color','rgb(255, 112, 0)');
lateNavy.style.setProperty('background-image','url("recycled-orange.png")');
window.__AD_HOMECOLOR453__();
assert(lateNavy.style.getPropertyValue('background-color')==='rgb(255, 112, 0)','recycled card retained stale navy');
assert(lateNavy.style.getPropertyValue('background-image').includes('url("recycled-orange.png")'),'recycled card retained a stale authored image');
assert(lateNavy.__adHomeAuth452.color==='rgb(255, 112, 0)','recycled authored color did not refresh');
assert(lateNavy.__adHomeAuth452.image==='url("recycled-orange.png")','recycled authored image did not refresh');

lateNavy.style.setProperty('background-color','rgb(118, 52, 160)');
window.__AD_HOMECOLOR453__();
window.__AD_HOMECOLOR453__();
assert(lateNavy.style.getPropertyValue('background-color')==='rgb(118, 52, 160)','color-only recycle was not adopted');
assert(lateNavy.style.getPropertyValue('background-image').includes('url("recycled-orange.png")'),'color-only recycle lost the existing authored image');
assert((lateNavy.style.getPropertyValue('background-image').match(/linear-gradient/g)||[]).length===1,'recycled card stacked duplicate overlays');
assert(/captured=5 tamed=5 missing=0 lostAuthored=0/.test(window.__AD_HOMECOLOR453_STATE__),'state does not prove both fixes: '+window.__AD_HOMECOLOR453_STATE__);
console.log('home-carousel-453 fixture: PASS (late/recycled authored colors survive; every non-video backing has one uniform overlay; child media unchanged)');
'''

result = subprocess.run(
    [NODE, "-e", prelude + capture + early_guard + after_capture + owner + assertions],
    text=True,
    capture_output=True,
)
if result.stdout:
    print(result.stdout, end="")
if result.stderr:
    print(result.stderr, end="", file=sys.stderr)
raise SystemExit(result.returncode)

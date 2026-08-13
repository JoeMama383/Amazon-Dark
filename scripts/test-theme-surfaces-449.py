#!/usr/bin/env python3
"""Lock v5.449's structural Compare-minus and direct Home-creative raster."""

from pathlib import Path
import importlib.util
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "src/Tweak.xm"
NODE = shutil.which("node")

if not NODE:
    print("theme-surfaces-449 fixture: SKIP (node not installed)")
    raise SystemExit(0)

source = SOURCE.read_text(encoding="utf-8")
native_start = source.index("// ── v5.449 STRUCTURAL COMPARE-TRAY MINUS")
native_end = source.index("// ── P19 VOICE-PERMISSION", native_start)
native = source[native_start:native_end]

native_required = [
    "ADCompareTryLeaf449",
    "[v isKindOfClass:[UIImageView class]]",
    "w<8 || w>30 || h<6 || h>30",
    "CGRectGetMidY(lf)<sh*.68",
    "CGRectGetMidX(lf)>sw*.46",
    "ADCompareTrayForLeaf449",
    "f.size.width>=win.bounds.size.width*.72",
    "f.size.height>=48 && f.size.height<=230",
    "ADCompareThumbWalk448(tray,tray,win,0,&thumb,&thumbScore)",
    "ADCompareRoundForLeaf449",
    "ADCompareDarkRaster449",
    "dx>52 || dy>42",
    "kADCompareOverlay449Key",
    "bar.name=@\"AmazonDark.compareMinus449\"",
    "bw=MAX(8.0,MIN(14.0,hw*.42))",
    "bh=MAX(2.0,MIN(3.0,hh*.09))",
    "bar.backgroundColor=ADColorFromHex(gP.fgHex).CGColor",
    "P92COMPARE449[nodes=",
    "hostStable=%d",
]
missing = [token for token in native_required if token not in native]
if missing:
    print("theme-surfaces-449 fixture: FAIL (structural Compare contract missing: " + ", ".join(missing) + ")")
    raise SystemExit(1)

for forbidden in [
    "host.backgroundColor=", "host.layer.backgroundColor=",
    "host.layer.cornerRadius=", "host.frame=", "host.bounds=",
    "[host setFrame:", "[host setBounds:", "[iv setImage:",
    "kADCompareImage448Key", "ADNativeComparePhrase448",
]:
    if forbidden in native:
        print("theme-surfaces-449 fixture: FAIL (native raster/host can be changed: " + forbidden + ")")
        raise SystemExit(1)

for token in [
    "ADFixNativeCompare449();",
    "objc_getAssociatedObject(self, kADCompareOverlay449Key)",
    "CGColorRef paint449=want449.CGColor",
    "%orig(paint449)",
    "const char *cn449=object_getClassName(self);",
    "(strstr(cn449,\"RCTImage\") || strstr(cn449,\"ImageComponent\"))",
]:
    if token not in source:
        print("theme-surfaces-449 fixture: FAIL (persistent native pin missing: " + token + ")")
        raise SystemExit(1)

if source.count("ADScheduleNativeCompare449();") < 2:
    print("theme-surfaces-449 fixture: FAIL (Compare scan lacks mount + image-assignment triggers)")
    raise SystemExit(1)

spec = importlib.util.spec_from_file_location("lint_js", ROOT / "scripts/lint-js.py")
lint_js = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lint_js)
emitted = lint_js.literals_in(lint_js.function_body(source, "ADProbeWebJS")).replace("%%", "%")
home_start = emitted.index("function homeCreative449(){")
home_end = emitted.index("try{if(!window.__AD_HOMEMEDIA449_WRAP__", home_start)
home_function = emitted[home_start:home_end]

home_required = [
    "img[class*=\"_single-creative-card\"],img[class*=\"single-creative-card\"]",
    "r449.width<220||r449.height<300",
    "/single-creative-card/i.test(c449)",
    "/single-video-card/i.test(c449)",
    "removeAttribute('data-ad-tame-fast362')",
    "removeAttribute('data-ad-homemedia395')",
    "setProperty('filter','none','important')",
    "setAttribute('data-ad-homecreative449','native-image')",
    "homeCreative449Native",
]
missing = [token for token in home_required if token not in home_function]
if missing:
    print("theme-surfaces-449 fixture: FAIL (Home raster contract missing: " + ", ".join(missing) + ")")
    raise SystemExit(1)

for token in [
    "__AD_HOMEMEDIA395_PRE449__", "homeCreative449();", "__AD_THEME449_OBS__",
    "attributeFilter:['style','class','src']", "P93HOME449[creative=",
    "dimmed=", "stale=", "background=",
]:
    if token not in source:
        print("theme-surfaces-449 fixture: FAIL (persistent Home/probe contract missing: " + token + ")")
        raise SystemExit(1)

writer_guards = [
    "if(x.hasAttribute&&x.hasAttribute('data-ad-homecreative449')){x.removeAttribute('data-ad-tame-fast362');x.removeAttribute('data-ad-homemedia395');if(String(x.style.getPropertyValue('filter')||'')!=='none'||x.style.getPropertyPriority('filter')!=='important')x.style.setProperty('filter','none','important');x.__adTamed=0;delete x.__adTameSig;x.__adBy='homeCreative449Native';continue;}",
    "if(e.hasAttribute&&e.hasAttribute('data-ad-homecreative449')){e.removeAttribute('data-ad-tame-fast362');e.removeAttribute('data-ad-homemedia395');if(String(e.style.getPropertyValue('filter')||'')!=='none'||e.style.getPropertyPriority('filter')!=='important')e.style.setProperty('filter','none','important');e.__adTamed=0;delete e.__adTameSig;e.__adBy='homeCreative449Native';continue;}",
]
for guard in writer_guards:
    if source.count(guard) != 1:
        print("theme-surfaces-449 fixture: FAIL (legacy dimmer is not exactly gated)")
        raise SystemExit(1)

for forbidden in [
    "theming-card-background", "getBoundingClientRect?", "ov449(",
    ".click(", "dispatchEvent", "createElement('svg')", "innerHTML=", "outerHTML=",
]:
    if forbidden in home_function:
        print("theme-surfaces-449 fixture: FAIL (Home direct-raster owner broadened: " + forbidden + ")")
        raise SystemExit(1)

fixture = r'''
class Style {
  constructor(){this.values=new Map();this.priorities=new Map();}
  setProperty(k,v,p=''){this.values.set(String(k),String(v));this.priorities.set(String(k),String(p));}
  getPropertyValue(k){return this.values.get(String(k))||'';}
  getPropertyPriority(k){return this.priorities.get(String(k))||'';}
  removeProperty(k){const old=this.getPropertyValue(k);this.values.delete(String(k));this.priorities.delete(String(k));return old;}
}
class Element {
  constructor(tag,cls,w,h){this.tagName=tag.toUpperCase();this.className=cls;this.rect={left:0,top:0,width:w,height:h,right:w,bottom:h};this.attrs=new Map();this.style=new Style();this.__adBy='';}
  getBoundingClientRect(){return this.rect;}
  setAttribute(k,v){this.attrs.set(k,String(v));}
  getAttribute(k){return this.attrs.has(k)?this.attrs.get(k):null;}
  hasAttribute(k){return this.attrs.has(k);}
  removeAttribute(k){this.attrs.delete(k);}
}
const creative=new Element('img','_single-creative-card_style_image__kEmO2',299,478);
creative.setAttribute('data-ad-tame-fast362','1');creative.setAttribute('data-ad-homemedia395','1');
creative.style.setProperty('filter','brightness(0.5) saturate(1.08)','important');creative.__adBy='whiteTameFast365';creative.__adTamed=1;creative.__adTameSig='old';
const small=new Element('img','_single-creative-card_style_logo__x',120,80);small.style.setProperty('filter','brightness(0.5)','important');
const video=new Element('img','_single-video-card_style_poster__x',299,478);video.style.setProperty('filter','brightness(0.5)','important');
const background=new Element('div','theming-card-background',299,478);background.style.setProperty('background-color','rgb(8,31,58)','important');

global.window=global;window.__ADFRAME_MODE__=false;
global.document={body:{},querySelector(){return null;},querySelectorAll(selector){
  if(selector==='img[class*="_single-creative-card"],img[class*="single-creative-card"]')return [creative,small];
  return [];
}};
global.getComputedStyle=e=>({filter:e.style.getPropertyValue('filter')||'none'});
function assert(ok,message){if(!ok)throw new Error(message);}

assert(homeCreative449()===1,'full-card creative was not acquired: '+window.__AD_HOMECREATIVE449_STATE__);
assert(creative.getAttribute('data-ad-homecreative449')==='native-image','native raster marker missing');
assert(creative.style.getPropertyValue('filter')==='none','brightness filter survived');
assert(!creative.hasAttribute('data-ad-tame-fast362')&&!creative.hasAttribute('data-ad-homemedia395'),'stale tame marker survived');
assert(creative.__adBy==='homeCreative449Native'&&creative.__adTamed===undefined&&creative.__adTameSig===undefined,'stale owner survived');
assert(small.style.getPropertyValue('filter')==='brightness(0.5)','small creative child was broadened into full-card owner');
assert(video.style.getPropertyValue('filter')==='brightness(0.5)','video guard was altered');
assert(background.style.getPropertyValue('background-color')==='rgb(8,31,58)','unrelated theming background was altered');
assert(/native=1 clean=1 dim=0 foreign=1/.test(window.__AD_HOMECREATIVE449_STATE__),'state lacks acquisition proof: '+window.__AD_HOMECREATIVE449_STATE__);

console.log('theme-surfaces-449 fixture: PASS (bottom-tray raster/host immutable; bounded light minus pinned; full-card creative filter released; video/background untouched)');
'''

result = subprocess.run([NODE, "-e", home_function + fixture], text=True, capture_output=True)
if result.stdout:
    print(result.stdout, end="")
if result.stderr:
    print(result.stderr, end="", file=sys.stderr)
raise SystemExit(result.returncode)

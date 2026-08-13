#!/usr/bin/env python3
"""Lock v5.450's Compare paint and Home authored-color/taming boundary."""

from pathlib import Path
import importlib.util
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "src/Tweak.xm"
NODE = shutil.which("node")

if not NODE:
    print("theme-surfaces-450 fixture: SKIP (node not installed)")
    raise SystemExit(0)

source = SOURCE.read_text(encoding="utf-8")
native_start = source.index("// ── v5.450 LOCAL-STRUCTURE COMPARE CONTROL")
native_end = source.index("// ── P19 VOICE-PERMISSION", native_start)
native = source[native_start:native_end]

native_required = [
    "ADCompareTryLeaf450",
    "ADCompareTrayForLeaf450",
    "ADCompareThumbWalk450(p,p,leaf,0,&localThumb,&localScore)",
    "w>=240 && w<=900 && h>=44 && h<=260 && w/h>=1.8",
    "w>=38 && w<=104 && h>=30 && h<=96",
    "dx>=-16 && dx<=64 && dy<=42",
    "ADCompareDarkRaster450",
    "kADCompareCircle450Key",
    "kADCompareMinus450Key",
    'circle.name=@"AmazonDark.compareCircle450"',
    'minus.name=@"AmazonDark.compareMinus450"',
    "circle.backgroundColor=[UIColor whiteColor].CGColor",
    "minus.backgroundColor=ADColorFromHex(gP.bgHex).CGColor",
    "P94COMPARE450[nodes=",
    "geometryStable=%d",
    "const double delay450[]={0.01,0.08,0.25,0.70,1.50,3.00}",
]
missing = [token for token in native_required if token not in native]
if missing:
    print("theme-surfaces-450 fixture: FAIL (Compare contract missing: " + ", ".join(missing) + ")")
    raise SystemExit(1)

for forbidden in [
    "CGRectGetMidY(lf)<", "win.bounds", "bottom-band",
    "host.backgroundColor=", "host.layer.backgroundColor=",
    "host.layer.cornerRadius=", "host.frame=", "host.bounds=",
    "[host setFrame:", "[host setBounds:", "[iv setImage:",
]:
    if forbidden in native:
        print("theme-surfaces-450 fixture: FAIL (Compare owner broadened: " + forbidden + ")")
        raise SystemExit(1)

source_required = [
    "objc_getAssociatedObject(self, kADCompareCircle450Key)",
    "CGColorRef circle450=[UIColor whiteColor].CGColor",
    "%orig(circle450)",
    "objc_getAssociatedObject(self, kADCompareMinus450Key)",
    "UIColor *dark450=ADColorFromHex(gP.bgHex)",
    "%orig(minus450)",
    "ADFixNativeCompare450();",
    "ADScheduleNativeCompare450();",
    "P94HOME450[colored=",
]
missing = [token for token in source_required if token not in source]
if missing:
    print("theme-surfaces-450 fixture: FAIL (persistent contract missing: " + ", ".join(missing) + ")")
    raise SystemExit(1)

if source.count("ADScheduleNativeCompare450();") < 4:
    print("theme-surfaces-450 fixture: FAIL (Compare lacks mount/image/layout triggers)")
    raise SystemExit(1)

for retired in [
    "function homeCreative449", "homeCreative449Native",
    "__AD_HOMEMEDIA449_WRAP__", "ADFixNativeCompare449(void)",
    "ADScheduleNativeCompare449(void)",
]:
    if retired in source:
        print("theme-surfaces-450 fixture: FAIL (failed v5.449 writer still active: " + retired + ")")
        raise SystemExit(1)

spec = importlib.util.spec_from_file_location("lint_js", ROOT / "scripts/lint-js.py")
lint_js = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lint_js)
emitted = lint_js.literals_in(lint_js.function_body(source, "ADProbeWebJS")).replace("%%", "%")
home_start = emitted.index("try{if(!window.__AD_HOMECOLOR450_WRAP__")
home_end = emitted.index("try{homeColor450();setTimeout", home_start)
home_block = emitted[home_start:home_end]

home_required = [
    "function homeColor450()",
    "[class*=theming-card-background]",
    "data-ad-homecolor450",
    "Math.max(q450[0],q450[1],q450[2])-Math.min(q450[0],q450[1],q450[2])<24",
    "e450.style.removeProperty('box-shadow')",
    "e450.style.removeProperty('background-blend-mode')",
    "e450.removeAttribute('data-ad-homebg395')",
    "e450.hasAttribute('data-ad-homecolor450')",
    "return false",
    "[data-ad-homecreative449]",
    "z450.style.removeProperty('filter')",
    "_adHomeMedia395()",
    "stale449=",
]
missing = [token for token in home_required if token not in home_block]
if missing:
    print("theme-surfaces-450 fixture: FAIL (Home contract missing: " + ", ".join(missing) + ")")
    raise SystemExit(1)

for forbidden in [
    "setProperty('filter','none','important')",
    "setAttribute('data-ad-homecreative449'",
    "single-video-card", ".click(", "dispatchEvent", "createElement('svg')",
]:
    if forbidden in home_block:
        print("theme-surfaces-450 fixture: FAIL (Home owner broadened: " + forbidden + ")")
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
  constructor(tag,cls,w,h,bg){this.tagName=tag.toUpperCase();this.className=cls;this.rect={left:0,top:0,width:w,height:h,right:w,bottom:h};this.nativeBackground=bg;this.attrs=new Map();this.style=new Style();this.__adBy='';}
  getBoundingClientRect(){return this.rect;}
  setAttribute(k,v){this.attrs.set(k,String(v));}
  getAttribute(k){return this.attrs.has(k)?this.attrs.get(k):null;}
  hasAttribute(k){return this.attrs.has(k);}
  removeAttribute(k){this.attrs.delete(k);}
}
const colored=new Element('div','theming-card-background',299,478,'rgb(0, 70, 125)');
colored.setAttribute('data-ad-homebg395','1');colored.__adBy='homeBgLeaf395';colored.__adTamed=1;colored.__adTameSig='old';
colored.style.setProperty('filter','none','important');colored.style.setProperty('background-blend-mode','normal','important');colored.style.setProperty('box-shadow','inset 0 0 0 9999px rgba(0,0,0,.225)','important');
const transparent=new Element('div','theming-card-background',299,478,'rgba(0, 0, 0, 0)');
transparent.setAttribute('data-ad-homebg395','1');transparent.__adBy='homeBgLeaf395';transparent.style.setProperty('box-shadow','inset 0 0 0 9999px rgba(0,0,0,.225)','important');
const creative=new Element('img','_single-creative-card_style_image__x',299,478,'rgba(0,0,0,0)');
creative.setAttribute('data-ad-homecreative449','native-image');creative.style.setProperty('filter','none','important');creative.__adBy='homeCreative449Native';
global.window=global;window.__ADFRAME_MODE__=false;window.__ADTAME_ON__=true;
global.document={body:{},querySelector(){return null;},querySelectorAll(selector){
  if(selector==='[data-ad-homecreative449]')return creative.hasAttribute('data-ad-homecreative449')?[creative]:[];
  if(selector==='[class*=theming-card-background]')return [colored,transparent];
  return [];
}};
global.getComputedStyle=e=>({
  backgroundColor:e.nativeBackground,
  boxShadow:e.style.getPropertyValue('box-shadow')||'none',
  backgroundBlendMode:e.style.getPropertyValue('background-blend-mode')||'normal',
  filter:e.style.getPropertyValue('filter')||'none'
});
let legacyCalls=0,retameCalls=0;
function _adHomeBgLeaf395(e){legacyCalls++;return true;}
function _adHomeMedia395(){retameCalls++;creative.setAttribute('data-ad-tame-fast362','1');creative.setAttribute('data-ad-homemedia395','1');creative.style.setProperty('filter','brightness(0.775) saturate(1.08)','important');creative.__adBy='homeMedia395';return 1;}
function assert(ok,message){if(!ok)throw new Error(message);}
'''

assertions = r'''
assert(homeColor450()===1,'saturated authored backing was not acquired: '+window.__AD_HOMECOLOR450_STATE__);
assert(colored.getAttribute('data-ad-homecolor450')==='authored','authored marker missing');
assert(!colored.hasAttribute('data-ad-homebg395')&&colored.__adBy===undefined,'old background owner survived');
assert(colored.style.getPropertyValue('box-shadow')===''&&colored.style.getPropertyValue('background-blend-mode')===''&&colored.style.getPropertyValue('filter')==='','old compositor survived');
assert(getComputedStyle(colored).backgroundColor==='rgb(0, 70, 125)','Amazon navy was replaced');
assert(!transparent.hasAttribute('data-ad-homecolor450'),'transparent neighbor was broadened into color owner');
assert(transparent.hasAttribute('data-ad-homebg395')&&transparent.style.getPropertyValue('box-shadow').includes('9999px'),'transparent neighbor lost taming');
assert(!creative.hasAttribute('data-ad-homecreative449'),'failed v5.449 image marker survived');
assert(creative.hasAttribute('data-ad-tame-fast362')&&creative.hasAttribute('data-ad-homemedia395'),'creative image was not returned to taming');
assert(getComputedStyle(creative).filter.includes('brightness'),'creative image remains untamed');
assert(retameCalls===1,'canonical retame did not run exactly once');
assert(_adHomeBgLeaf395(colored)===false,'marked authored backing re-entered compositor');
assert(_adHomeBgLeaf395(transparent)===true&&legacyCalls===1,'unmarked backing stopped using legacy owner');
assert(/colored=1 restored=1 bad=0 stale449=1/.test(window.__AD_HOMECOLOR450_STATE__),'state lacks ownership proof: '+window.__AD_HOMECOLOR450_STATE__);
console.log('theme-surfaces-450 fixture: PASS (light circle/dark minus; authored navy compositor-free; creative image taming retained)');
'''

result = subprocess.run([NODE, "-e", prelude + home_block + assertions], text=True, capture_output=True)
if result.stdout:
    print(result.stdout, end="")
if result.stderr:
    print(result.stderr, end="", file=sys.stderr)
raise SystemExit(result.returncode)

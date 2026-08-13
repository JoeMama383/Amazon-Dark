#!/usr/bin/env python3
"""Lock v5.454's visual-neutral scheduling and rounded Home card clip."""

from pathlib import Path
import hashlib
import importlib.util
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "src/Tweak.xm"
NODE = shutil.which("node")
source = SOURCE.read_text(encoding="utf-8")


def between(start: str, end: str, label: str) -> str:
    try:
        a = source.index(start)
        b = source.index(end, a)
        return source[a:b]
    except ValueError:
        print(f"performance-bleed-454 fixture: FAIL (missing {label})")
        raise SystemExit(1)


def require(body: str, tokens: list[str], label: str) -> None:
    missing = [token for token in tokens if token not in body]
    if missing:
        print(f"performance-bleed-454 fixture: FAIL ({label} missing: {', '.join(missing)})")
        raise SystemExit(1)


def reject(body: str, tokens: list[str], label: str) -> None:
    found = [token for token in tokens if token in body]
    if found:
        print(f"performance-bleed-454 fixture: FAIL ({label} contains: {', '.join(found)})")
        raise SystemExit(1)


checkbox_paint = between(
    "         // v5.441 DEVICE-CAPTURED STOCK CHECKBOX + SHARED 32PX CHROME.",
    '         "try{window.__AD_CHECKBOX434__=stockCheckbox434;',
    "stock checkbox paint body",
)
if hashlib.sha256(checkbox_paint.encode()).hexdigest() != "c255f1d269c09616544e7125c459bb7bd4f8bb7d41e77438cca09701425c36aa":
    print("performance-bleed-454 fixture: FAIL (solved checkbox painter changed)")
    raise SystemExit(1)

checkbox_scheduler = between(
    '         "try{window.__AD_CHECKBOX434__=stockCheckbox434;',
    "         // v5.347 PDP HEART.",
    "checkbox scheduler",
)
require(
    checkbox_scheduler,
    [
        "function queue434(ms434)",
        "new MutationObserver(function(){queue434(24);}",
        "addEventListener('scroll',function(){queue434(320);}",
        "if(!window.__ADSCROLLING__||ms434<100)",
        "attributeFilter:['class','aria-checked','aria-pressed','aria-selected','data-checked','data-selected','data-state','checked','src','data-src']",
    ],
    "checkbox coalescing",
)
reject(checkbox_scheduler, ["'style'", "requestAnimationFrame(r434)"], "checkbox self-feedback guard")

runtime_observer = between(
    "         // v5.454: retain every v5.452 painter and its order",
    "         \"try{new MutationObserver(function(){try{cartChrome382();}",
    "shared runtime observer",
)
require(
    runtime_observer,
    [
        "function queueRuntime454(ms454)",
        "if(window.__ADSCROLLING__){queueRuntime454(220);return;}",
        "window.requestIdleCallback(run454,{timeout:420})",
        "new MutationObserver(function(){queueRuntime454(96);}",
        "attributeFilter:['class','aria-current','aria-selected','data-selected','data-state','checked','src','data-src']",
    ],
    "shared idle scheduler",
)
reject(
    runtime_observer,
    ["'style'", "'fill'", "'stroke'", "data-darkreader-inline-bgcolor", "data-darkreader-inline-color"],
    "shared observer feedback guard",
)

focused = between(
    "static void ADFocusedProbe363(void){",
    "// ── NATIVE HAIRLINE / BORDER SWEEP",
    "automatic WKWebView installer",
)
runtime_extract = between(
    "static NSString *ADRuntimeWebJS454(void){",
    "// Lightweight, idempotent production runtime installation",
    "runtime-only extractor",
)
require(
    runtime_extract + focused,
    [
        'rangeOfString:@"/*V5313FIX*/"',
        'rangeOfString:@"/*V5395FIX*/"',
        "ADRuntimeWebJS454()",
        "P97PERF454[runtimeOnly=1 fullProbe=0]",
        "P98BLEED454[hosts=",
    ],
    "runtime-only automatic path",
)
reject(focused, ["evaluateJavaScript:ADProbeWebJS()"], "automatic full diagnostic path")
if source.count("evaluateJavaScript:ADProbeWebJS()") < 1:
    print("performance-bleed-454 fixture: FAIL (explicit full probe was removed)")
    raise SystemExit(1)

native_scroll = between(
    "@interface ADScrollSettle454 : NSObject",
    "// ════════════════════════════════════════════════════════════════════════════════\n// SURFACE 4",
    "native trailing scroll guard",
)
require(
    native_scroll,
    [
        "CFTimeInterval lastMotion;",
        "state->lastMotion=CACurrentMediaTime();",
        "s.tracking || s.dragging || s.decelerating || quiet < 0.22",
        'ADSweepTimed(s, NO, "scroll454")',
        "ADSubscribeOverlay394(x394)",
        "ADHeaderProbe();",
    ],
    "true native trailing edge",
)
reject(native_scroll, ["ADSweepTimed(ss, NO, \"scroll\")"], "old during-scroll deadline")

video = []
for line in source.splitlines():
    if "_adHomeVideo391" not in line:
        continue
    if line.lstrip().startswith('"homeAmbient386();'):
        line = line.replace('"homeAmbient386();', '"}catch(e){}}""homeAmbient386();', 1)
    video.append(line)
if len(video) != 5:
    print("performance-bleed-454 fixture: FAIL (Home video call-site count changed)")
    raise SystemExit(1)
video_lines = "\n".join(video)
if hashlib.sha256(video_lines.encode()).hexdigest() != "7f6f56ed65addf48812d33e75cc7eae5b6e2eec268be6a4f7062334713e632cd":
    print("performance-bleed-454 fixture: FAIL (Home video bytes changed)")
    raise SystemExit(1)

bleed_source = between(
    "         // v5.454 HOME BLEED CLIP.",
    '         "homeAmbient386();badgeFix()',
    "Home bleed clip",
)
require(
    bleed_source,
    [
        "function _adHomeClipOne454(e454,A454)",
        "window.__AD_HOMECLIP454__=function()",
        "data-ad-homeclip454",
        "--ad-homeclip454-radius",
        "overflow:hidden !important",
        "clip-path:inset(.5px round var(--ad-homeclip454-radius,12px))",
        "window.__AD_HOMECOLOR452_PRE454__",
    ],
    "rounded card-host clip",
)
require(source, ["P98BLEED454[hosts="], "bleed device probe")
reject(
    bleed_source,
    [
        "new MutationObserver(", "addEventListener('scroll'", "setProperty('filter'",
        "setProperty('transform'", "setProperty('background'", "setProperty('background-color'",
        "setProperty('background-image'", "setProperty('width'", "setProperty('height'",
        ".play(", ".pause(", ".click(", "dispatchEvent",
    ],
    "bleed fix scope",
)

if not NODE:
    print("performance-bleed-454 fixture: SKIP DOM behavior (node not installed)")
    raise SystemExit(0)

spec = importlib.util.spec_from_file_location("lint_js", ROOT / "scripts/lint-js.py")
lint_js = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lint_js)
runtime = lint_js.literals_in(lint_js.function_body(source, "ADProbeWebJS")).replace("%%", "%")
bleed_start = runtime.index("function _adHomeClipOne454")
bleed_end = runtime.index("homeAmbient386();badgeFix()", bleed_start)
bleed_js = runtime[bleed_start:bleed_end]

prelude = r'''
class Style {
  constructor(){this.values=new Map();}
  setProperty(k,v){this.values.set(String(k),String(v));}
  getPropertyValue(k){return this.values.get(String(k))||'';}
  removeProperty(k){const v=this.getPropertyValue(k);this.values.delete(String(k));return v;}
}
class Element {
  constructor(tag,cls,left,top,width,height,radius=0){
    this.nodeType=1;this.tagName=tag.toUpperCase();this.className=cls;this.style=new Style();
    this.attrs=new Map();this.parentElement=null;this.children=[];this.radius=radius;
    this.rect={left,top,width,height,right:left+width,bottom:top+height};
  }
  appendChild(e){e.parentElement=this;this.children.push(e);return e;}
  getBoundingClientRect(){return this.rect;}
  setAttribute(k,v){this.attrs.set(String(k),String(v));}
  getAttribute(k){return this.attrs.has(String(k))?this.attrs.get(String(k)):null;}
  hasAttribute(k){return this.attrs.has(String(k));}
  removeAttribute(k){this.attrs.delete(String(k));}
  querySelectorAll(sel){
    const out=[];const walk=e=>{for(const c of e.children){if(sel==='[data-ad-homecolor452="authored"]'&&c.getAttribute('data-ad-homecolor452')==='authored')out.push(c);walk(c);}};walk(this);return out;
  }
}
const html=new Element('html','',0,0,430,900),body=new Element('body','',0,0,430,900);
html.appendChild(body);
const outer=new Element('div','carousel-lane',0,180,430,520,0);body.appendChild(outer);
const host=new Element('article','single-creative-card theming-card',65,190,300,478,12);outer.appendChild(host);
const inner=new Element('div','theming-card-background-shell',45,190,340,478,0);host.appendChild(inner);
const backing=new Element('div','theming-card-background',45,190,340,478,0);inner.appendChild(backing);
backing.setAttribute('data-ad-homecolor452','authored');backing.style.setProperty('background-color','rgb(0, 70, 125)');
const image=new Element('img','_single-creative-card_style_image__x',65,190,300,478,0);host.appendChild(image);
image.style.setProperty('filter','brightness(0.775) saturate(1.08)');
const styles=new Map();
const head={appendChild(e){styles.set(e.id,e);return e;}};
global.window=global;window.__ADFRAME_MODE__=false;global.innerWidth=430;
global.setTimeout=()=>1;global.clearTimeout=()=>{};
global.document={body,documentElement:html,head,
  createElement(tag){return {tagName:String(tag).toUpperCase(),id:'',textContent:'',style:new Style(),attrs:new Map(),setAttribute(k,v){this.attrs.set(k,v);}};},
  getElementById(id){return styles.get(id)||null;},
  querySelector(){return null;},
  querySelectorAll(sel){
    const all=[];const walk=e=>{if(sel==='[data-ad-homecolor452="authored"]'&&e.getAttribute&&e.getAttribute('data-ad-homecolor452')==='authored')all.push(e);if(sel==='[data-ad-homeclip454="1"]'&&e.getAttribute&&e.getAttribute('data-ad-homeclip454')==='1')all.push(e);for(const c of e.children||[])walk(c);};walk(html);return all;
  }
};
global.getComputedStyle=e=>({
  borderTopLeftRadius:(e.radius||0)+'px',borderTopRightRadius:(e.radius||0)+'px',
  borderBottomLeftRadius:(e.radius||0)+'px',borderBottomRightRadius:(e.radius||0)+'px'
});
function assert(ok,msg){if(!ok)throw new Error(msg);}
'''

assertions = r'''
assert(host.getAttribute('data-ad-homeclip454')==='1','rounded card host was not marked');
assert(!outer.hasAttribute('data-ad-homeclip454'),'carousel lane was clipped instead of the card');
assert(!inner.hasAttribute('data-ad-homeclip454'),'unrounded same-size wrapper won over rounded card host');
assert(!backing.hasAttribute('data-ad-homeclip454'),'oversized background clipped only to itself');
assert(host.style.getPropertyValue('--ad-homeclip454-radius')==='12px','authored card radius was not retained');
const sheet=document.getElementById('adhomeclip454');
assert(sheet&&sheet.textContent.includes('overflow:hidden !important'),'host overflow clip is missing');
assert(sheet.textContent.includes('clip-path:inset(.5px round var(--ad-homeclip454-radius,12px))'),'rounded compositor clip is missing');
assert(backing.style.getPropertyValue('background-color')==='rgb(0, 70, 125)','bleed fix changed backing color');
assert(image.style.getPropertyValue('filter')==='brightness(0.775) saturate(1.08)','bleed fix changed child media WBT');
assert(/owned=1 hosts=1 missing=0/.test(window.__AD_HOMECLIP454_STATE__),'clip state lacks one-to-one coverage: '+window.__AD_HOMECLIP454_STATE__);
backing.removeAttribute('data-ad-homecolor452');window.__AD_HOMECLIP454__();
assert(!host.hasAttribute('data-ad-homeclip454')&&!host.style.getPropertyValue('--ad-homeclip454-radius'),'stale recycled host clip was not cleaned');
console.log('performance-bleed-454 fixture: PASS (v5.452 painters frozen; feedback work coalesced; runtime-only navigation; rounded host clip is paint/media neutral)');
'''

result = subprocess.run([NODE, "-e", prelude + bleed_js + assertions], text=True, capture_output=True)
if result.stdout:
    print(result.stdout, end="")
if result.stderr:
    print(result.stderr, end="", file=sys.stderr)
raise SystemExit(result.returncode)

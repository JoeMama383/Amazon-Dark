#!/usr/bin/env python3
"""Lock v5.448's native Compare-minus and Home-creative paint boundaries."""

from pathlib import Path
import importlib.util
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "src/Tweak.xm"
NODE = shutil.which("node")

if not NODE:
    print("theme-surfaces-448 fixture: SKIP (node not installed)")
    raise SystemExit(0)

spec = importlib.util.spec_from_file_location("lint_js", ROOT / "scripts/lint-js.py")
lint_js = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lint_js)
source = SOURCE.read_text(encoding="utf-8")
emitted = lint_js.literals_in(lint_js.function_body(source, "ADProbeWebJS")).replace("%%", "%")

home_start = emitted.index("function homeCreative448(){")
home_end = emitted.index("function homeAmbient386(){", home_start)
home_function = emitted[home_start:home_end]

# Probe-derived native ownership.  P89=0 proved the web DOM is not an eligible
# owner; the repeated native 10x14 glyphs are pinned only after semantic, tray,
# thumbnail, round-host, and nested-leaf checks all agree.
native_required = [
    'ADNativeComparePhrase448',
    '@"Compare with similar"',
    '@"keep selecting"',
    'if (ADIsWebKitOwned(v)) return nil;',
    'ADCompareThumbWalk448',
    'w>=24 && w<=96 && h>=24 && h<=96',
    'ADCompareDarkRound448',
    'w<18 || w>52 || h<18 || h>52',
    'ADCompareViewCandidate448(v,v,0)',
    'ADCompareHostWalk448(tray,tray,thumb,win,0,&host,&hs)',
    'if (v!=host)',
    'kADCompareImage448Key',
    'kADCompareSolid448Key',
    'kADCompareText448Key',
    'kADCompareLayer448Key',
    '[iv setImage:cur]',
    'P90COMPARE448[text=1',
    'hostStable=%d',
]
missing = [token for token in native_required if token not in source]
if missing:
    print("theme-surfaces-448 fixture: FAIL (native Compare contract missing: " + ", ".join(missing) + ")")
    raise SystemExit(1)

for forbidden in [
    'host.backgroundColor=', 'host.layer.backgroundColor=',
    'host.layer.cornerRadius=', '[host setFrame:', '[host setBounds:',
    'objc_setAssociatedObject(host,kADCompareImage448Key',
    'objc_setAssociatedObject(host,kADCompareSolid448Key',
    'objc_setAssociatedObject(host,kADCompareText448Key',
    'objc_setAssociatedObject(host,kADCompareLayer448Key',
]:
    if forbidden in source:
        print("theme-surfaces-448 fixture: FAIL (native Compare host can be mutated: " + forbidden + ")")
        raise SystemExit(1)

first_paint_required = [
    "[class*=theming-card-background]:not([data-ad-homecreative448]){background-color:initial !important;}",
    "replace(/data-ad-homecreative447/g,'data-ad-homecreative448')",
    "[class*=single-video-card] [class*=theming-card-background]",
    "if(e448&&e448.hasAttribute&&e448.hasAttribute('data-ad-homecreative448'))return false",
]
missing = [token for token in first_paint_required if token not in source]
if missing:
    print("theme-surfaces-448 fixture: FAIL (Home release boundary missing: " + ", ".join(missing) + ")")
    raise SystemExit(1)

for required in [
    "document.querySelectorAll('[class*=theming-card-background]')",
    "img[class*=\"_single-creative-card\"]",
    "img[class*=\"_single-video-card\"]",
    "ia448/ma448>.72",
    "if(vi448)continue",
    "setAttribute('data-ad-homecreative448','native')",
    "removeProperty('box-shadow')",
    "removeAttribute('data-ad-homebg395')",
]:
    if required not in home_function:
        print("theme-surfaces-448 fixture: FAIL (Home overlap contract missing: " + required + ")")
        raise SystemExit(1)

for forbidden in [
    "setProperty('background-color'", "setProperty('background'",
    ".click(", "dispatchEvent", "createElement('svg')", "innerHTML=", "outerHTML=",
]:
    if forbidden in home_function:
        print("theme-surfaces-448 fixture: FAIL (Home release invents paint/state: " + forbidden + ")")
        raise SystemExit(1)

fixture = r'''
class Style {
  constructor(){this.values=new Map();}
  setProperty(key,value){this.values.set(String(key),String(value));}
  getPropertyValue(key){return this.values.get(String(key))||'';}
  removeProperty(key){const old=this.getPropertyValue(key);this.values.delete(String(key));return old;}
}
class Element {
  constructor(tag,className,rect){this.tagName=tag.toUpperCase();this.className=className||'';this.rect={...rect,right:rect.left+rect.width,bottom:rect.top+rect.height};this.attrs=new Map();this.style=new Style();this.__adBy='';this.nativeBackground='rgb(8,31,58)';}
  getBoundingClientRect(){return this.rect;}
  setAttribute(k,v){this.attrs.set(k,String(v));}
  getAttribute(k){return this.attrs.has(k)?this.attrs.get(k):null;}
  hasAttribute(k){return this.attrs.has(k);}
  removeAttribute(k){this.attrs.delete(k);}
}
const all=[];
function add(tag,cls,left,top,width,height){const e=new Element(tag,cls,{left,top,width,height});all.push(e);return e;}
const creativeImage=add('img','_single-creative-card_style_image__kEmO2',20,180,299,478);
const creativeBg=add('div','theming-card-background',20,180,299,478);
creativeBg.setAttribute('data-ad-homebg395','1');creativeBg.__adBy='homeBgLeaf395';
creativeBg.style.setProperty('filter','none');creativeBg.style.setProperty('background-blend-mode','normal');creativeBg.style.setProperty('box-shadow','inset 0 0 0 9999px rgba(0,0,0,.225)');
const videoImage=add('img','_single-video-card_style_poster__x',340,180,299,478);
const videoBg=add('div','theming-card-background',340,180,299,478);videoBg.nativeBackground='rgb(84,24,16)';

global.window=global;window.__ADFRAME_MODE__=false;
global.document={body:{},querySelector(selector){return null;},querySelectorAll(selector){
  if(selector==='[class*=theming-card-background]')return [creativeBg,videoBg];
  if(selector.includes('_single-creative-card'))return [creativeImage];
  if(selector.includes('_single-video-card'))return [videoImage];
  return [];
}};
global.getComputedStyle=e=>({backgroundColor:e.hasAttribute('data-ad-homecreative448')?e.nativeBackground:'rgb(24,26,27)',backgroundImage:'none'});
function assert(ok,message){if(!ok)throw new Error(message);}

assert(homeCreative448()===1,'overlapping sibling creative was not released: '+String(window.__AD_HOMECREATIVE448_STATE__));
assert(creativeBg.getAttribute('data-ad-homecreative448')==='native','creative background did not receive native marker');
assert(!videoBg.hasAttribute('data-ad-homecreative448'),'overlapping video background was released');
assert(getComputedStyle(creativeBg).backgroundColor==='rgb(8,31,58)','Amazon native navy did not return');
assert(getComputedStyle(videoBg).backgroundColor==='rgb(24,26,27)','video black guard was lost');
assert(!creativeBg.hasAttribute('data-ad-homebg395')&&creativeBg.__adBy===undefined,'old Home background owner remains');
assert(!creativeBg.style.getPropertyValue('filter')&&!creativeBg.style.getPropertyValue('background-blend-mode')&&!creativeBg.style.getPropertyValue('box-shadow'),'old v5.395 dim overlay remains');
assert(!creativeBg.style.getPropertyValue('background-color')&&!creativeBg.style.getPropertyValue('background'),'release invented a replacement color');
assert(/native=1 cleanup=1/.test(window.__AD_HOMECREATIVE448_STATE__),'state did not prove release+cleanup: '+window.__AD_HOMECREATIVE448_STATE__);

console.log('theme-surfaces-448 fixture: PASS (native minus leaf pinned; host immutable; sibling navy creative restored; video guard retained)');
'''

result = subprocess.run([NODE, "-e", home_function + fixture], text=True, capture_output=True)
if result.stdout:
    print(result.stdout, end="")
if result.stderr:
    print(result.stderr, end="", file=sys.stderr)
raise SystemExit(result.returncode)

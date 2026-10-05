from pathlib import Path
import json,subprocess,shutil,tempfile
from payload_source import block,strings
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text()
J=''.join(json.loads(l) for l in (R/'src/ADNewMenus7482.js.inc').read_text().splitlines() if l.strip())
css=J.split('s.textContent=`',1)[1].split('`;',1)[0]
b=block(T,'ADPharmacyMediaJS7563');fmt=strings(b)
assert 'gP.whiteTame?' in b and 'gP.whiteTameStrength' in b
# CI compiles the exact Objective-C++ media helper; local environments without
# Clang still execute the emitted JS and cascade fixture below.
if shutil.which('clang++'):
 with tempfile.TemporaryDirectory() as td:
  mm=Path(td)/'pharmacy.mm'
  mm.write_text("""#define MAX(a,b) ((a)>(b)?(a):(b))
#define MIN(a,b) ((a)<(b)?(a):(b))
typedef double CGFloat;
@interface NSString
+ (id)stringWithFormat:(id)format, ...;
@end
struct ADPrefs { int whiteTame; int whiteTameStrength; };
static ADPrefs gP;
"""+b)
  subprocess.run(['clang++','-x','objective-c++','-std=gnu++98','-fsyntax-only',str(mm)],check=True,capture_output=True,text=True)
for f in (1.0,.9,.684,.42):
 js=fmt.replace('%.3f',f'{f:.3f}')
 harness="var captured='';global.document={getElementById:()=>null,createElement:()=>({}),head:{appendChild:s=>{Object.defineProperty(s,'textContent',{set:v=>captured=v})}}};"
 p=subprocess.run([shutil.which('node'),'-e',harness+js+";process.stdout.write(captured)"],capture_output=True,text=True)
 assert p.returncode==0,p.stderr
 assert f'brightness({f:.3f})' in p.stdout
 assert '.image>img' in p.stdout and 'filter:' in p.stdout
 assert 'MutationObserver' not in js and 'setInterval' not in js
assert 'ADPharmacyChrome7563(self,color)' in T
assert 'CXIStatusBarInsetBarComponentViewController' in T
try:
 import tinycss2,cssselect2
 from lxml import html
except ImportError:
 print('PASS: Pharmacy emitted media program/strengths; optional CSS matcher unavailable');raise SystemExit(0)
fixture='''<html><body><div id="a-page"><pui-sub-nav><pui-section class="pui-sub-nav-container" id="nav"></pui-section></pui-sub-nav><div data-csa-c-painter="pharmacy-lego-painter"><div id="hero" class="background-color-ghost-sage"><h2 id="title" class="heading color-squid">Title</h2><div class="image"><img id="art"/></div><a id="signup" class="button button-type-tertiary">Sign up</a><div id="pill" class="background-color-sage border-radius-4px"><span class="color-health-dark">Delivery</span></div></div><div id="prime" class="background-color-retail-prime"></div><div id="graytext" class="color-thunder"></div></div><div id="outside" class="background-color-white"></div></div></body></html>'''
m=cssselect2.Matcher()
for rule in tinycss2.parse_stylesheet(css,skip_comments=True,skip_whitespace=True):
 if rule.type!='qualified-rule':continue
 try:sels=cssselect2.compile_selector_list(tinycss2.serialize(rule.prelude))
 except cssselect2.SelectorError:continue
 ds=[d for d in tinycss2.parse_declaration_list(rule.content) if d.type=='declaration']
 for sel in sels:m.add_selector(sel,ds)
styles={}
for e in cssselect2.ElementWrapper.from_html_root(html.fromstring(fixture)).iter_subtree():
 wins={}
 for spec,order,pseudo,ds in m.match(e):
  if pseudo:continue
  for d in ds:
   key=(d.important,spec,order)
   if d.name not in wins or key>=wins[d.name][0]:wins[d.name]=(key,tinycss2.serialize(d.value).strip())
 if e.id:styles[e.id]={k:v[1] for k,v in wins.items()}
assert styles['hero']['background-color']=='#000'
assert styles['nav']['background']=='#000'
assert styles['title']['color']=='#fff'
assert styles['pill']['background-color']=='#303335'
assert styles['signup']['background']=='#000' and styles['signup']['border']=='1px solid #747a7c'
assert styles['graytext']['color']=='#b1b5b5'
assert 'background-color' not in styles['prime'] and 'background' not in styles['prime']
assert 'background-color' not in styles['outside']
assert 'filter' not in styles['art'] # Media program owns brightness separately, exactly once.
print('PASS: Pharmacy scoped cascade, semantic Prime banner, neutral text/buttons and large-image strength bounds')

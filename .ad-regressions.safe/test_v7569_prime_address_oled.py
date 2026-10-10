from pathlib import Path
import json,subprocess,tempfile,shutil
import tinycss2,cssselect2
from lxml import html
from payload_source import block,strings
R=Path(__file__).resolve().parents[1];T=(R/'src/Tweak.xm').read_text()
J=''.join(json.loads(l) for l in (R/'src/ADNewMenus7482.js.inc').read_text().splitlines() if l.strip());css=J.split('s.textContent=`',1)[1].split('`;',1)[0]
fixture='''<html><body><div class="discounts-react-app"><div id="floor" class="MobileDiscountAsinGrid-module__root_test"><div id="card" class="GridItem-module__container_test"><span id="title" class="a-color-base">Item</span><span id="deal" class="deal-badge">Deal</span><a id="link">Shop deals</a><i id="stars" class="a-icon-star"/><button id="plus" class="AddToCartButton-module__button_test"><span class="AddToCartButton-module__iconContainer_test"><svg id="glyph"/></span></button></div><button id="filter" class="RefinementPill-module__refinementPill_test">Brands</button></div></div><div class="a-popover"><div class="a-popover-wrapper" id="dialog"><h3 id="heading">Brands</h3><label id="option">Brand</label><span id="apply" class="a-button a-button-primary"><span id="inner" class="a-button-inner"><span id="text" class="a-button-text">Apply</span></span></span><input id="check" type="checkbox"/><i id="dialogstars" class="a-icon-star"/></div></div></body></html>'''
m=cssselect2.Matcher()
for rule in tinycss2.parse_stylesheet(css,skip_comments=True,skip_whitespace=True):
 if rule.type!='qualified-rule':continue
 try:sels=cssselect2.compile_selector_list(tinycss2.serialize(rule.prelude))
 except cssselect2.SelectorError:continue
 ds=[d for d in tinycss2.parse_declaration_list(rule.content) if d.type=='declaration']
 for sel in sels:m.add_selector(sel,ds)
out={}
for e in cssselect2.ElementWrapper.from_html_root(html.fromstring(fixture)).iter_subtree():
 wins={}
 for spec,order,pseudo,ds in m.match(e):
  if pseudo:continue
  for d in ds:
   key=(d.important,spec,order)
   if d.name not in wins or key>=wins[d.name][0]:wins[d.name]=(key,tinycss2.serialize(d.value).strip())
 if e.id:out[e.id]={k:v[1] for k,v in wins.items()}
for n in ('floor','card','dialog'):assert out[n]['background-color']=='#000',(n,out[n])
for n in ('plus','filter','apply'):assert out[n]['background']=='#000' and out[n]['border']=='1px solid #747a7c',(n,out[n])
for n in ('title','heading','option','text'):assert out[n]['color']=='#fff',(n,out[n])
assert out['glyph']['fill']=='#fff'
for n in ('link','deal','stars','dialogstars','check'):assert 'filter' not in out[n] and 'color' not in out[n],(n,out[n])
fmt=strings(block(T,'ADPrimeMediaJS7569'))
for f in (1.,.9,.684,.42):
 with tempfile.NamedTemporaryFile(suffix='.js',mode='w') as p:
  p.write(fmt%(f,f));p.flush();subprocess.run(['node','--check',p.name],check=True,capture_output=True)
# Compile the real native helper, including both button states and exact ancestor boundary.
prelude='''#include "service_sheet_uikit_stubs.h"
@interface NSNumber (GlowFixture)
+ (NSNumber *)numberWithBool:(BOOL)v;
@end
@interface UIColor (GlowFixture)
@property(readonly) void *CGColor;
@end
@interface CALayer : NSObject
@property void *borderColor;
@property CGFloat borderWidth;
@end
@interface UIView (GlowFixture)
@property(readonly) CALayer *layer;
@end
typedef unsigned long UIControlState;
enum { UIControlStateNormal=0,UIControlStateHighlighted=1,UIControlStateSelected=4 };
@interface UIButton : UIView
- (void)setTitleColor:(UIColor *)color forState:(UIControlState)state;
@end
static const void *kADGlowFloor7569=&kADGlowFloor7569;
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'glow.mm';p.write_text(prelude+T[T.index('static void ADGlowToaster7569'):T.index('%hook UIView',T.index('static void ADGlowToaster7569'))])
 result=subprocess.run([shutil.which('clang++'),'-x','objective-c++','-std=gnu++98','-fsyntax-only','-Wno-objc-root-class','-I',str(R/'tests/fixtures'),str(p)],text=True,capture_output=True)
 assert result.returncode==0,result.stderr
assert T.count('ADGlowToaster7569(self);')==2
print('PASS: native address dropdown helper compiles; Prime floors/buttons/filter dialogs, neutral copy, semantic exclusions and artwork strengths match policy')

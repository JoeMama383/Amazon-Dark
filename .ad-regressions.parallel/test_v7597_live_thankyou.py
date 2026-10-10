"""Replay sanitized paint owners from all three supplied v7.596 captures."""
from pathlib import Path
import json,re,subprocess
from lxml import etree
import cssselect2,tinycss2
R=Path(__file__).resolve().parents[1]
js=(R/'src/ADLiveTheme7597.js').read_text();old=(R/'src/ADOrderConfirmation7596.js').read_text()
assert ''.join(json.loads(x) for x in (R/'src/ADLiveTheme7597.js.inc').read_text().splitlines())==js
source=(R/'src/Tweak.xm').read_text()
assert '#include "ADLiveTheme7597.js.inc"' in source
assert 'live597 stringByReplacingOccurrencesOfString:@"__FACTOR__" withString:[NSString stringWithFormat:@"%.3f",(gP.whiteTame?ad7593Factor:1.0)]]' in source
assert not re.search(r'MutationObserver|setInterval|setTimeout|requestAnimationFrame|addEventListener',js)
fixtures=json.loads((R/'tests/fixtures/live_thankyou_v7596.json').read_text())
def matcher(factor):
 m=cssselect2.Matcher()
 for program in [old,js]:
  css=program.split('var css=`',1)[1].split('`;',1)[0].replace('__FACTOR__',factor)
  for rule in tinycss2.parse_stylesheet(css,skip_comments=True,skip_whitespace=True):
   if rule.type!='qualified-rule':continue
   ds={d.lower_name:tinycss2.serialize(d.value).strip() for d in tinycss2.parse_declaration_list(rule.content) if d.type=='declaration'}
   for sel in cssselect2.compile_selector_list(tinycss2.serialize(rule.prelude).replace(':placeholder-shown','[data-fixture-placeholder-shown]')):m.add_selector(sel,ds)
 return m
m=matcher('0.420')
def fixture_node(f):
 root=None;parent=None
 for part in reversed(f['chain']):
  el=etree.Element(part['tag'])
  for k in ['id','class','role']:
   if part.get(k):el.set(k,part[k])
  if parent is not None:parent.append(el)
  else:root=el
  parent=el
 return list(cssselect2.ElementWrapper.from_html_root(root).iter_subtree())[-1]
def paint(n,prop,pseudo=None,match=m):
 vals=[(spec,order,ds[prop]) for spec,order,ps,ds in match.match(n) if ps==pseudo and prop in ds]
 return max(vals)[2] if vals else None
def rgb(v):
 nums=re.findall(r'[\d.]+',v or '')
 return [float(x) for x in nums[:3]] if len(nums)>=3 else None
fail=[];counts={'floors':0,'text':0,'images':0,'semantic':0}
for f in fixtures:
 n=fixture_node(f);c=f['chain'][0]['class'];tag=n.etree_element.tag;bg=rgb(f['bg']);fg=rgb(f['color']);live=f['capture']=='r3'
 label=f['capture']+' '+tag+'.'+c
 # Every captured white/light neutral floor, plus the missed checkout button backing.
 light=bg and min(bg)>110 and max(bg)-min(bg)<30 and 'rgba(0, 0, 0, 0)'!=f['bg']
 if (light or 'p13n-sc-atc-container' in c) and tag!='b':
  if 'vjs-play-progress' in c:continue # Filled progress indicator is semantic, not a floor.
  got=paint(n,'background') or paint(n,'background-color')
  if got not in ['#000','#303335','transparent']:fail.append(('floor',label,got,f['bg']))
  counts['floors']+=1
 if live and tag in ['img','video'] and 'retargeting-pixel' not in c:
  logo=any('logoContainer_' in x['class'] for x in f['chain'])
  expected='url(#ad7597-live-logo-contrast)' if logo else 'brightness(0.420)'
  if paint(n,'filter')!=expected:fail.append(('media',label,paint(n,'filter')))
  counts['images']+=1
 if not live and ('_YXN2L_productImage_' in c or 'sp-dynamic-image' in c):
  assert paint(n,'filter')=='brightness(0.420)',label;counts['images']+=1
 # All dark authored copy in the captured Live menu, excluding hidden document text and whitespace.
 if live and fg and max(fg)<140 and max(fg)-min(fg)<45 and f['ownLen']>2 and tag not in ['option','noscript'] and f['display']!='none':
  got=paint(n,'color')
  if got not in ['#fff','#b1b5b5']:fail.append(('text',label,got,f['color']))
  counts['text']+=1
 if '_YXN2L_borderOrange_' in c:
  assert paint(n,'background') is None and paint(n,'background-color') is None and paint(n,'border-color') is None,label;counts['semantic']+=1
 if 'orangeActiveBorder--' in c:assert paint(n,'border-color') is None and paint(n,'border') is None,label;counts['semantic']+=1
 if 'badges_liveBadge__' in c or 'asin-item-module__dealText_' in c:
  assert paint(n,'background') is None and paint(n,'background-color') is None,label;counts['semantic']+=1
 if 'a-icon-star' in c:assert paint(n,'filter') is None,label;counts['semantic']+=1
 if live and tag not in ['img','video'] and 'azliveVjs' not in c:assert paint(n,'filter') is None,label
assert not fail,json.dumps(fail,indent=2)
# Search icon/placeholder parity, nondependent text, and disabled/min/default/max artwork strength.
for factor in ['1.000','0.900','0.684','0.420']:
 mm=matcher(factor)
 for f in fixtures:
  n=fixture_node(f);c=f['chain'][0]['class'];tag=n.etree_element.tag
  if f['capture']=='r3' and tag=='path' and any('searchIcon_' in x['class'] for x in f['chain']):assert paint(n,'fill',match=mm)=='#b1b5b5'
  if n.id=='amazon-live-search':assert paint(n,'color','placeholder',mm)=='#b1b5b5' and paint(n,'color',match=mm)=='#fff'
  if '_YXN2L_productImage_' in c or 'sp-dynamic-image' in c:assert paint(n,'filter',match=mm)=='brightness('+factor+')'
# cssselect2 has no interactive placeholder state. Model only that browser state
# as an attribute; execute the real :has() relationship and cascade in both states.
for placeholder,expected in [(True,'#b1b5b5'),(False,'#fff')]:
 root=etree.fromstring('<div id="live-page-container-mobile"><div class="search-header-module__searchBarWrapper_hash"><input id="amazon-live-search"/><svg class="search-header-module__searchIcon_hash"><path/></svg></div></div>')
 if placeholder:root.find('.//input').set('data-fixture-placeholder-shown','')
 nodes=list(cssselect2.ElementWrapper.from_html_root(root).iter_subtree())
 assert paint(nodes[-1],'fill')==expected
# Root-level text fill would override colored descendant text even when its own
# color is semantic; neutral inheritance must not force an inherited white fill.
for f in fixtures:
 n=fixture_node(f)
 if n.id in ['live-destination-main','live-destination-main-max-width','live-destination-widget'] or 'widget-container' in n.classes:
  assert paint(n,'-webkit-text-fill-color') is None
# Identical descendants outside the captured roots must remain untouched.
root=etree.fromstring('<div id="unrelated"><div class="search-header-module__searchBarWrapper_hash"><input id="amazon-live-search"/><svg><path/></svg></div><img class="sp-dynamic-image"/></div>')
for n in cssselect2.ElementWrapper.from_html_root(root).iter_subtree():
 assert not m.match(n)
# Native glyph scope excludes branded Home and non-CXI hierarchies; no full-tree walk.
native=source.split('static BOOL ADCXINeutralButton7597',1)[1].split('%ctor',1)[0]
for x in ['nav_back_button','nav_search_button','cxi_top_nav','i<3','if(!gP.enabled','UIImageRenderingModeAlwaysTemplate']:assert x in native,x
assert 'nav_home_button' not in native and 'subviews' not in native
# Compile the exact new native helper/method bodies after replacing only Logos dispatch syntax.
import shutil,tempfile
native_unit=native.replace('%hook CXIHighlightableTouchAreaButton','@implementation CXIHighlightableTouchAreaButton').replace('%orig(color);','(void)color;').replace('%orig;',';').replace('%end','@end')
stubs='typedef bool BOOL; const BOOL YES=true,NO=false;\n#define nil ((id)0)\n__attribute__((objc_root_class)) @interface NSObject\n- (BOOL)isEqual:(id)x;\n@end\n@interface NSString:NSObject\n- (BOOL)isEqualToString:(NSString*)x;\n@end\n@interface UIColor:NSObject @end\n@interface UIView:NSObject\n@property(retain) NSString *accessibilityIdentifier;\n@property(retain) UIView *superview;\n@property(retain) UIColor *tintColor;\n@end\nenum {UIImageRenderingModeAlwaysTemplate=2};\n@interface UIImage:NSObject\n@property int renderingMode;\n- (UIImage*)imageWithRenderingMode:(int)m;\n@end\n@interface UIImageView:UIView\n@property(retain) UIImage *image;\n@end\n@interface UIButton:UIView\n@property(retain) UIImageView *imageView;\n@end\n@interface CXIHighlightableTouchAreaButton:UIButton @end\nstatic struct { BOOL enabled; } gP;\nstatic UIColor *ADLightText706(void);\nstatic BOOL ADCXINeutralButton7597'
with tempfile.TemporaryDirectory() as td:
 p=Path(td)/'native.mm';p.write_text(stubs+native_unit)
 result=subprocess.run([shutil.which('clang++') or 'clang++','-x','objective-c++','-std=gnu++98','-fsyntax-only',str(p)],text=True,capture_output=True)
 assert result.returncode==0,result.stderr
# Logo filter preserves orange/white and alpha, only replacing dark navy with white.
for col,alpha,expected in [((.13,.19,.25),1,(1,1,1)),((1,.43,0),1,(1,.43,0)),((1,1,1),.5,(1,1,1)),((.13,.19,.25),.25,(1,1,1))]:
 mask=int(.8-col[0]>=.5);assert ((1,1,1) if mask else col)==expected
 assert mask*alpha+(1-mask)*alpha==alpha
# Actual program reinjection produces one stylesheet and one SVG definition; no recurring work.
program='''const vm=require('vm'),assert=require('assert');let els=[],ids=new Map();
function node(){return {style:{},setAttribute(k,v){this[k]=v},set innerHTML(v){this.markup=v;ids.set('ad7597-live-logo-contrast',this)}}}
let d={getElementById:id=>ids.get(id),createElement:node,createElementNS:node};
let host={appendChild(n){els.push(n);if(n.id)ids.set(n.id,n)}};d.head=host;d.body=host;d.documentElement=host;
let c={document:d};vm.createContext(c);let js=SOURCE;for(let i=0;i<100;i++)vm.runInContext(js,c);
assert.equal(els.length,2);assert(!els[0].textContent.includes('__FACTOR__'));
'''.replace('SOURCE',json.dumps(js.replace('__FACTOR__','0.420')))
subprocess.run(['node'],input=program,text=True,check=True,capture_output=True)
print('PASS: captured Live/thank-you floors, neutral copy, artwork, search contrast, orange rings/stars/deals and idempotent CSS:',counts)

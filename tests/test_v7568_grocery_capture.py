from pathlib import Path
import json,subprocess,tempfile
import tinycss2,cssselect2
from lxml import html
from payload_source import block,strings
R=Path(__file__).resolve().parents[1]
def decode(name):return ''.join(json.loads(l) for l in (R/'src'/name).read_text().splitlines() if l.strip())
j=decode('ADNewMenus7482.js.inc');css=j.split('s.textContent=`',1)[1].split('`;',1)[0]
fixture='''<html><body><div class="alm-storefront-container-mobile-zones" id="floor"><div class="pui-carousel-container-mobile" id="carousel"><h2 id="header">Deals</h2><span class="a-color-base" id="price">Price</span><span class="a-color-success" id="semantic">Open</span><a id="link">Details</a><span class="a-button a-button-primary qs-rounded-atc qs-atc-plus" id="plus"><span class="a-button-inner" id="inner"><button class="a-button-text" id="label">+</button></span></span><img id="logo" class="brand-logo"/><hr id="divider"/></div></div><div class="unrelated"><span class="a-button" id="outside"/></div></body></html>'''
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
assert styles['floor']['background']=='#000'
assert styles['carousel']['background-color']=='#000'
for n in ('header','price','label'):assert styles[n]['color']=='#fff',(n,styles[n])
assert styles['plus']['background']=='#000' and styles['plus']['border-color']=='#747a7c'
assert styles['inner']['background']=='transparent'
assert styles['divider']['border-color']=='#494d4d'
for n in ('semantic','link','logo','outside'):assert 'color' not in styles[n] and 'filter' not in styles[n],(n,styles[n])
T=(R/'src/Tweak.xm').read_text();fmt=strings(block(T,'ADGroceryMediaJS7568'))
for f in (1.,.9,.684,.42):
 js=fmt%(f,f,f*255,f*255,f*255)
 with tempfile.NamedTemporaryFile(mode='w',suffix='.js') as p:
  p.write(js);p.flush();subprocess.run(['node','--check',p.name],check=True,capture_output=True)
 assert 'brightness(%.3f)'%f in js
 assert 'background-blend-mode:multiply' in js
# Execute bounded diagnostic on a dense document. The tiny hit grid sees only root;
# the inventory must still find the visible button and report its neutral paint.
js=decode('ADUIImmediate7568.js.inc')
harness=r'''
const style=new Proxy({display:'block',visibility:'visible',opacity:'1',backgroundImage:'none',color:'rgb(0, 0, 0)'},{get:(o,k)=>o[k]||'0px'});
function el(id){return {nodeType:1,id,tagName:'BUTTON',className:'',children:[],parentElement:null,firstChild:null,hasAttribute:()=>false,getBoundingClientRect:()=>({x:1,y:1,width:40,height:30,right:41,bottom:31}),getAttribute:()=>null};}
const root=el('root');root.tagName='HTML';root.scrollHeight=900;root.scrollTop=0;root.children=Array.from({length:9000},(_,i)=>el('button'+i));for(const c of root.children)c.parentElement=root;
global.window={innerWidth:400,innerHeight:800,scrollY:0};global.document={documentElement:root,body:root,scrollingElement:root,elementsFromPoint:()=>[root],getElementById:()=>null};global.getComputedStyle=()=>style;
const result=JSON.parse(eval(SOURCE));if(!result.nodes.some(n=>n.attrs.id==='button0'))throw Error('grid-only regression');if(result.nodes.length>1800||!result.counts.truncated)throw Error('unbounded or silent truncation');
'''.replace('SOURCE',json.dumps(js))
result=subprocess.run(['node','-e',harness],capture_output=True,text=True)
assert result.returncode==0,result.stderr
U=(R/'src/ADUniversalUIProbe7362.inc').read_text()
assert 'TRIGGER_REJECTED reason=capture-already-running' not in U
assert 'UIApplication.sharedApplication.connectedScenes' in U
assert 'SCREENSHOT_INITIAL_VISIBLE_DOM' in U
assert 'ADUIImmediateEvidence7568(YES,@"armed-background-during-full")' in U
assert 'previousName compare:name' in U
print('PASS: grocery CSS cascade, semantic/logo exclusions, artwork strength bounds, dense visible inventory and capture-boundary contracts')

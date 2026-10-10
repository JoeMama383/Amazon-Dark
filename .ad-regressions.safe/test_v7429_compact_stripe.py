"""Execute the actual TWB payload at three strengths and verify banner ownership."""
from pathlib import Path
import json,subprocess
from payload_source import payload
ROOT=Path(__file__).resolve().parents[1]
src=(ROOT/'src/Tweak.xm').read_text()
runner=r'''
const vm=require('vm'),assert=require('assert'),styles={};
const host={appendChild(s){s.isConnected=true;styles[s.id]=s}};
const document={readyState:'complete',head:host,documentElement:host,getElementById(id){return styles[id]},createElement(){return {remove(){delete styles[this.id]}}}};
const window={};window.top=window;
let c={document,window,location:{hostname:'www.amazon.com',pathname:'/'}};
vm.runInNewContext(process.argv[1],c);vm.runInNewContext(process.argv[1],c);
assert.equal(Object.keys(styles).length,1);
let css=styles['ad7-menu-twb'].textContent;
vm.runInNewContext(process.argv[2],c);assert.equal(Object.keys(styles).length,0);
console.log(JSON.stringify(css));
'''
selector='#a-page hp-stripe hp-lucid-wrapper > a.stripe'
for strength in [0,45,100]:
 css=json.loads(subprocess.check_output(['node','-e',runner,payload(src,'ADTWBJS',strength),payload(src,'ADTWBClearJS791')],text=True))
 factor=f'{1-(.1+.48*strength/100):.3f}'
 first=css.split('}',1)[0]
 assert first.startswith(selector+',') and 'brightness('+factor+')' in first
 assert selector+' :is(img,video,canvas){filter:none!important;-webkit-filter:none!important;opacity:1!important;mix-blend-mode:normal!important;}' in css
# Optional CSS matcher verifies observed DOM roles and rejects unrelated banners.
try:
 import cssselect2
 from lxml import html
except ImportError:
 print('SKIP: optional selector matcher (cssselect2/lxml unavailable)')
else:
 tree=html.fromstring('<div id="a-page"><hp-stripe><hp-lucid-wrapper><a id="banner" class="stripe"><span>Headline</span><div class="stripe-media-container"><video id="video"></video><img id="raster"></div></a></hp-lucid-wrapper></hp-stripe><a id="other" class="stripe"><video id="other-video"></video></a></div>')
 nodes=list(cssselect2.ElementWrapper.from_html_root(tree).iter_subtree())
 def matches(s):
  test=cssselect2.compile_selector_list(s)[0].test
  return {n.id for n in nodes if test(n)}
 assert matches(selector)=={'banner'}
 assert matches(selector+' :is(img,video,canvas)')=={'video','raster'}
print('PASS: compact banner strength 0/45/100, single owner, media reset, reinjection and preference cleanup')

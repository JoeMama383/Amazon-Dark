from pathlib import Path
import json,subprocess
from payload_source import block,strings
ROOT=Path(__file__).resolve().parents[1]
src=(ROOT/'src/Tweak.xm').read_text()
js=strings(block(src,'ADPDPCompletionJS7405'))
fmt=strings(block(src,'ADPDPCompletionTWBJS7405'))
# Execute emitted scripts, including repeated hydration, child isolation, and all
# brightness endpoints. No browser/iOS rendering is claimed by this test.
runner=r'''
const vm=require('vm'),assert=require('assert');
const payload=JSON.parse(process.argv[1]);
function context(child,ref){const styles={};const root={appendChild(s){assert(!styles[s.id]);styles[s.id]=s;}};const window={};window.top=child?{}:window;return {styles,ctx:{window,document:{referrer:ref,head:root,documentElement:root,getElementById(id){return styles[id]},createElement(){return {}}}}};}
let c=context(false,'');vm.runInNewContext(payload.js,c.ctx);vm.runInNewContext(payload.js,c.ctx);
assert.equal(Object.keys(c.styles).length,1);let css=c.styles['ad7405-pdp-completion'].textContent;
assert(css.includes('#attach-accessory-card-deck .attach-atc-button{background:#303335'));
assert(css.includes('#dp#dp .ape-placement{background-color:#000'));
assert(!css.includes('#dp img{'));
let unrelated=context(true,'https://www.amazon.com/gp/cart/view.html');vm.runInNewContext(payload.js,unrelated.ctx);assert.equal(Object.keys(unrelated.styles).length,0);
let child=context(true,'https://www.amazon.com/dp/B012345678');vm.runInNewContext(payload.js,child.ctx);assert(child.styles['ad7405-pdp-child-ad']);assert(!child.styles['ad7405-pdp-completion']);
for(const item of payload.taming){let c=context(false,'');vm.runInNewContext(item.js,c.ctx);vm.runInNewContext(item.js,c.ctx);assert.equal(Object.keys(c.styles).length,1);let css=c.styles['ad7405-pdp-twb'].textContent;assert(css.includes('brightness('+item.factor+')'));assert(!css.includes('trackingPixel'));assert(!css.includes('display:'));assert(!css.includes('visibility:'));}
'''
taming=[]
for strength in [0,45,100]:
 factor=f'{1-(.1+.48*strength/100):.3f}';taming.append(dict(js=fmt.replace('%.3f',factor),factor=factor))
subprocess.run(['node','-e',runner,json.dumps(dict(js=js,taming=taming))],check=True)
print('PASS: PDP/child isolation, repeat injection and media brightness 0/45/100')

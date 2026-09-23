from pathlib import Path
import json,re,subprocess
from payload_source import block,strings
R=Path(__file__).resolve().parents[1]
s=(R/'src/Tweak.xm').read_text()
main=strings(block(s,'ADPDPUICompletionJS7439'))
twb=block(s,'ADPDPCompletionTWBJS7405')
fmt=strings(twb[twb.index('[NSString stringWithFormat:'):])
assert re.findall(r'%[.0-9]*f',fmt)==['%.3f']*4+['%.0f']*3
# Execute the actual generated payloads, collect emitted CSS, and syntax-check at both strength bounds.
for strength in [0,100]:
 factor=1-(.10+.48*strength/100)
 vals=iter([factor]*4+[factor*255]*3)
 js=re.sub(r'%\.(\d+)f',lambda m:f'{next(vals):.{m[1]}f}',fmt)
 harness="""const vm=require('vm');let sheets=[];const d={referrer:'',getElementById:()=>null,createElement:()=>({}),head:{appendChild:s=>sheets.push(s)}};const w={};w.top=w;const c={document:d,window:w};for(const p of PAYLOADS)vm.runInNewContext(p,c);process.stdout.write(JSON.stringify(sheets.map(s=>s.textContent)));""".replace('PAYLOADS',json.dumps([main,js]))
 sheets=json.loads(subprocess.check_output(['node','-e',harness],text=True))
 css=''.join(sheets)
 assert '_multi-bundle-mobile_image-display__]{mix-blend-mode:normal!important;background:transparent!important;opacity:1!important;}' in css
 assert '#dp #aplusBrandStory_feature_div img,' in css
 assert '#dp [class*=_p13n-mobile-sims-multi-bundle_multi-bundle-mobile_image-display__] img.p13n-product-image,' in css
 assert f'background-color:rgb({factor*255:.0f},{factor*255:.0f},{factor*255:.0f})!important;background-blend-mode:multiply!important;filter:none!important;' in css
 assert f'brightness({factor:.3f})' in css
 assert 'Version: 7.457~screenshot-share-diagnostic' in (R/'layout/DEBIAN/control').read_text()
print('PASS: v7.454 executes media styles at both strength bounds; wrapper blending releases loaded images and only artwork receives dimming')

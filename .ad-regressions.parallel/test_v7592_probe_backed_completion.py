"""Captured owner/cascade and late custom-element regressions, not screenshot guesses."""
import json, subprocess, re
from pathlib import Path
import cssselect2, tinycss2
from lxml import html
R=Path(__file__).resolve().parents[1]
js=''.join(json.loads(x) for x in (R/'src/ADNewMenus7482.js.inc').read_text().splitlines())
css=js.split('s.textContent=`',1)[1].split('`;',1)[0]
m=cssselect2.Matcher()
for rule in tinycss2.parse_stylesheet(css,skip_comments=True,skip_whitespace=True):
    if rule.type!='qualified-rule':continue
    try: selectors=cssselect2.compile_selector_list(tinycss2.serialize(rule.prelude))
    except cssselect2.SelectorError:continue
    ds={d.lower_name:(tinycss2.serialize(d.value).strip(),d.important) for d in tinycss2.parse_declaration_list(rule.content) if d.type=='declaration'}
    for sel in selectors:m.add_selector(sel,ds)
fixture='''<html><body>
<div id="main-content" class="ap-lego"><a id="nav-link-health-ai-mobile"></a>
<div class="kyanite-condition-picker-search"><div class="search-input-container" id="search-outer"><div class="pui-input-container"><i class="pui-icon search-icon" id="magnifier"></i></div></div></div>
<button class="upsell-banner-cta" id="cta">Get started</button><button id="pui-input-right-button" class="pui-button">send</button>
</div>
<pui-section class="section-container" id="confirm"><pui-section id="privacy-banner"><i class="security-lock-icon"></i></pui-section><h1 class="black-color" id="confirm-title">Confirm</h1><p class="dark-grey-color" id="secondary">Gray</p><a class="link-color" id="dynamic">Edit</a><button class="pui-button" id="continue">Continue</button></pui-section>
<form id="verification-code-form"></form><div class="a-global-nav-wrapper" id="logo-strip"><i class="a-icon-logo" id="logo"></i></div><div class="a-divider-inner" id="divider"></div>
<div id="warblerApplicationRoot"><div data-testid="wfe-cos-quick-actions" id="actions"></div><div data-testid="wfe-input-container" id="input"></div><svg><path stroke="#000" fill="none" id="hollow"/><path fill="#000" id="solid"/><path fill="#09f" id="blue"/></svg></div>
<div id="dp"><div id="promoPriceBlockMessage_feature_div"><div class="ct-coupon-tile claimed"><svg id="couponSuccessIconpctch6768943225923642"><path id="circle"/><path id="check"/></svg></div><div class="ct-coupon-tile unclaimed"><i class="a-icon a-icon-checkbox" id="unclaimed"/></div></div></div>
</body></html>'''
nodes={e.etree_element.get('id'):e for e in cssselect2.ElementWrapper.from_html_root(html.fromstring(fixture)).iter_subtree() if e.etree_element.get('id')}
def paint(id,prop,pseudo=None):
    wins=[((ds[prop][1],spec,order),ds[prop][0]) for spec,order,ps,ds in m.match(nodes[id]) if ps==pseudo and prop in ds]
    return max(wins)[1] if wins else None
for node,prop,value in [('search-outer','background','transparent'),('magnifier','filter','brightness(0) invert(1)'),('cta','background','#000'),('cta','color','#fff'),('pui-input-right-button','border','0'),('confirm','background-color','#000'),('confirm-title','color','#fff'),('secondary','color','#b1b5b5'),('continue','background','#000'),('logo-strip','background','#000'),('logo','filter','invert(1) hue-rotate(180deg)'),('circle','fill','#000'),('check','fill','#fff')]:
    assert paint(node,prop)==value,(node,prop,paint(node,prop))
assert paint('dynamic','color') is None
assert paint('unclaimed','filter') is None
assert paint('hollow','fill') is None # Never fill the hollow location/outline geometry.
assert paint('hollow','stroke')=='#fff'
assert paint('solid','fill')=='#fff'
assert paint('blue','fill') is None
assert paint('actions','background','after')=='transparent'
assert paint('input','background','before')=='transparent'
assert paint('divider','background','after')=='#000'
# Execute actual shadow delivery after an initially absent component upgrades.
start=js.index('function ad7585WarblerShadow()')
end=js.index('/*',js.index("window.customElements.whenDefined(tag).then(ad7591MedicalShadowPass);",start)) if '/*' in js[js.index("window.customElements.whenDefined(tag).then(ad7591MedicalShadowPass);",start):] else len(js)
# Extract only the shadow delivery group, excluding the payload's outer closure.
end=js.index("// Interests uses the accepted rules",start) # include the idempotent listener installation guard
program=r'''
const assert=require('assert'); let ready=false, callbacks={}, events={}, styles=[];
const shadow={querySelector(s){return styles.find(x=>'#'+x.id===s)||null},appendChild(x){styles.push(x)}};
const host={shadowRoot:shadow};
const d={querySelector(s){return ready&&s==='#warblerApplicationRoot arc-button[data-testid=wfe-sidebar-cid-signin-btn]'?host:null},createElement(){return {}},addEventListener(n,f){events[n]=f}};
const window={addEventListener(){},customElements:{whenDefined(tag){return new Promise(resolve=>callbacks[tag]=resolve)}}};
'''+js[start:end]+r'''
assert.equal(styles.length,0);ready=true;callbacks['arc-button']();
Promise.resolve().then(()=>{assert.equal(styles.length,1);assert(styles[0].textContent.includes('border:1px solid #747a7c'));ad7591MedicalShadowPass();assert.equal(styles.length,1);console.log('late-upgrade shadow delivery OK')});
'''
subprocess.run(['node'],input=program,text=True,check=True,capture_output=True)
s=(R/'src/Tweak.xm').read_text()
f=s[s.index('static BOOL ADPDPThumbnailImage7588'):s.index('static void ADPDPApplyThumbnailTWB7588')]
limit=int(re.search(r'for\(int d=0;n&&d<(\d+)',f).group(1))
# All eight 41px probe thumbnails have SNP root at ancestor depth 10.
assert 10 in range(limit)
additive=s[s.index('static void ADPDPApplyThumbnailTWB7588'):s.index('static void ADApplyNativeTWBCached7183',s.index('static void ADPDPApplyThumbnailTWB7588'))]
assert 'removeFromSuperlayer' not in additive
assert 'kADShopShowOriginalClip7592' in s
print('PASS: v7.592 real owner cascade, semantic negatives, late shadow upgrade, thumbnail depth and additive media preservation')

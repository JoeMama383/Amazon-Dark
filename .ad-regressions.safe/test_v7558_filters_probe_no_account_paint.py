"""v7.619: captured Filters + universal Account probe routing, with no speculative Account paint."""
from pathlib import Path
import json
R=Path(__file__).resolve().parents[1]
control=(R/'layout/DEBIAN/control').read_text(); t=(R/'src/Tweak.xm').read_text(); u=(R/'src/ADUniversalUIProbe7362.inc').read_text(); script=(R/'scripts/ui-probe.sh').read_text()
assert 'Version: 7.619~handoff-regression-repair' in control
assert '#define AD_VERSION "v7.619-handoff-regression-repair"' in t
js=''.join(json.loads(line) for line in (R/'src/ADNewMenus7482.js.inc').read_text().splitlines() if line.strip())
css=js.split('s.textContent=`',1)[1].split('`;',1)[0]
# Earlier Filters fixes remain.
for token in ('#dropdown-content-s-all-filters','.sf-filters-vtabs-tabs-container','.s-vtabs-contents-container','body:has(#dropdown-content-s-all-filters) .sf-bottom-nav.sf-bottom-nav-current{border-top:1px solid #494d4d!important;border-bottom:0!important;background:#000!important;}','a.sf-bottom-nav-btn.sf-show-results{background:#000!important;background-color:#000!important;border:1px solid #747a7c!important'):
    assert token in css, token
# Selected options now match normal medium-gray options without clobbering authored blue selection border.
sel='#dropdown-content-s-all-filters #sf-filters-vtabs :is(a,span).sf-filter-floatbox.s-filter-item-selected{background:#303335!important;background-color:#303335!important;box-shadow:none!important;color:#fff!important;-webkit-text-fill-color:#fff!important;}'
assert sel in css
selected=css.split(':is(a,span).sf-filter-floatbox.s-filter-item-selected{',1)[1].split('}',1)[0]
assert 'border' not in selected, selected
# Price panel is floor-only OLED: no color/filter/border changes to blue/white authored contents.
needle='#dropdown-content-s-all-filters #priceRefinements #filter-p_36>.sf-filter-section.s-no-js-hide{'
price=css.split(needle,1)[1].split('}',1)[0]
assert price=='background:#000!important;background-color:#000!important;', price
# Do not theme Account speculatively: production Person ownership is back to exact #me ancestry only.
for banned in ('kADPersonRedirectedRoot7557','kADPersonRedirectedRoot7558','ADPersonRedirectedRoot7557','ADPersonRedirectedRoot7558','ADPersonPhysicalMajority7557','ADPersonPhysicalMajority7558'):
    assert banned not in t, banned
rootfn=t[t.index('static UIView *ADPersonRoot7206(UIView *v){'):t.index('static BOOL ADInPersonTab7206',t.index('static UIView *ADPersonRoot7206(UIView *v){'))]
assert 'accessibilityIdentifier isEqualToString:@"me"' in rootfn
assert 'return nil;' in rootfn
surface=t[t.index('static int ADReactSurface7226(UIView *v){'):t.index('static UIView *ADAlexaResultsRoot7427')]
assert 'if(ADPersonRoot7206(v))' not in surface
# Probe routing still rejects a covered retained Person root and falls through to universal visible-renderer capture.
assert 'static BOOL ADUIOwnsMajority7557' in u or 'static BOOL ADUIOwnsMajority7558' in u
assert 'ADUIViewActuallyVisible7362(v)&&ADUIOwnsMajority' in u
capture=u[u.index('static void ADCaptureUniversalUIProbe7362(BOOL viewportOnly,NSString *trigger){'):u.index('static NSString *ADUIViewportArmPath7362')]
assert capture.index('UIView *menuWrap=ADUIMenuWrapper7520();') < capture.index('UIView *personWrap=ADUIPersonWrapper7519();') < capture.index('ADUIDetectPDPSession7451(webs,^')
# VIEWPORT arm is consumed before busy check and captures immediately instead of disappearing behind FULL.
handler=u[u.index('static void ADUIHandleWillResignActive7447'):u.index('static void ADCaptureThreeTabProbe7254')]
assert handler.index('ADUIConsumeViewportArm7362()') < handler.index('gADUIProbeBusy7362')
assert 'ADUIImmediateEvidence7568(YES,@"armed-background-during-full")' in handler
assert 'gADUIViewportQueued7557=YES' not in handler
assert 'VIEWPORT capture is queued or still running' in script
# Optional real cascade proof.
try:
    import tinycss2, cssselect2
    from lxml import html
except ImportError:
    print('PASS: v7.619 Filters/probe/no-Account-paint structural contracts; SKIP optional CSS cascade')
    raise SystemExit(0)
fixture='<html><body><div id="dropdown-content-s-all-filters"><div id="sf-filters-vtabs"><span id="selected" class="sf-filter-floatbox s-filter-item-selected"><span id="label">Featured</span></span><a id="normal" class="sf-filter-floatbox"><span>Low to High</span></a><div id="priceRefinements"><div id="filter-p_36"><div id="hist" class="sf-filter-section s-no-js-hide"><span id="blue">bars</span></div></div></div></div></div><div id="footer" class="sf-bottom-nav sf-bottom-nav-current"><a id="results" class="sf-bottom-nav-btn sf-show-results"><span id="count">Show results</span></a></div></body></html>'
css2=css+'\n.s-filter-item-selected{background:rgb(237,248,255)!important;border:2px solid rgb(33,98,161)!important}.sf-filter-section{background:rgb(244,244,244)!important}.sf-show-results{background:#ffd814!important}'
matcher=cssselect2.Matcher()
for rule in tinycss2.parse_stylesheet(css2,skip_comments=True,skip_whitespace=True):
    if rule.type!='qualified-rule': continue
    try: sels=cssselect2.compile_selector_list(tinycss2.serialize(rule.prelude))
    except cssselect2.SelectorError: continue
    ds=[d for d in tinycss2.parse_declaration_list(rule.content,skip_comments=True,skip_whitespace=True) if d.type=='declaration']
    for sel in sels: matcher.add_selector(sel,ds)
styles={}
for el in cssselect2.ElementWrapper.from_html_root(html.fromstring(fixture)).iter_subtree():
    eid=el.etree_element.get('id'); wins={}
    for spec,order,pseudo,ds in matcher.match(el):
        if pseudo: continue
        for d in ds:
            rank=(d.important,spec,order)
            if d.name not in wins or rank>=wins[d.name][0]: wins[d.name]=(rank,tinycss2.serialize(d.value).strip())
    if eid: styles[eid]={k:v[1] for k,v in wins.items()}
assert styles['selected']['background']=='#303335',styles['selected']
assert styles['selected']['border']=='2px solid rgb(33,98,161)',styles['selected']
assert styles['selected']['-webkit-text-fill-color']=='#fff'
assert styles['normal']['background']=='#303335'
assert styles['hist']['background']=='#000'
assert 'background' not in styles.get('blue',{}),styles.get('blue',{})
assert styles['results']['background']=='#000'
assert styles['results']['border']=='1px solid #747a7c'
assert styles['footer']['border-top']=='1px solid #494d4d'
assert styles['footer']['border-bottom']=='0'
print('PASS: v7.619 Filters selected/price/footer + universal FULL/VIEWPORT routing; Account paint intentionally deferred')

"""Golden semantic contracts derived from the supplied v7.386 source, plus execution tests.
No browser, account, npm package or third-party Python dependency is required.
"""
from pathlib import Path
import hashlib,json,re,subprocess,shutil,os
from payload_source import payload,block
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text();A=(ROOT/'src/ADSponsored.m').read_text()
golden=json.loads((ROOT/'tests/v7386_semantic_baseline.json').read_text())
def digest(s):return hashlib.sha256(s.encode()).hexdigest()
# v7.389+v7.390 intentionally append probe-scoped checkout/UI rules.
# Remove that exact floor span and the one v7.390 checkout-TWB Maple selector before
# verifying the older v7.386/v7.387 golden programs.
from cart7423_delta import strip_cart7423, strip_byg7423
from video7425_delta import strip_video7425
S_golden=strip_video7425(strip_byg7423(strip_cart7423(S)))
# v7.424 broadens only the BYG renderer ownership. Normalize those exact approved
# checkout-floor deltas back to v7.420 before comparing the v7.386 semantic golden.
S_golden=S_golden.replace(
    ",[class*=_speed-byg-sf-mobile-carousel_style_carouselContainer_]", "")
S_golden=S_golden.replace(
    "#checkoutDisplayPage .checkout-byg-mobile-container button[name='submit.addToCart']{background:#303335!important;border:1px solid #747a7c!important;border-color:#747a7c!important;outline:none!important;outline-color:transparent!important;box-shadow:none!important;color:#e8e6e3!important;-webkit-tap-highlight-color:transparent!important;}#checkoutDisplayPage .checkout-byg-mobile-container button[name='submit.addToCart']:is(:focus,:focus-visible,:active){background:#202324!important;border-color:#747a7c!important;outline:none!important;outline-color:transparent!important;box-shadow:none!important;}#checkoutDisplayPage .checkout-byg-mobile-container button[name='submit.addToCart'] .a-icon-small-add{filter:brightness(0) invert(1)!important;-webkit-filter:brightness(0) invert(1)!important;opacity:1!important;}",
    "#checkoutDisplayPage .checkout-byg-mobile-container [class*=_denseGridAxSpotAtcButton_] button[name='submit.addToCart']{background:#303335!important;border:1px solid #747a7c!important;border-color:#747a7c!important;outline:none!important;outline-color:transparent!important;box-shadow:none!important;color:#e8e6e3!important;-webkit-tap-highlight-color:transparent!important;}#checkoutDisplayPage .checkout-byg-mobile-container [class*=_denseGridAxSpotAtcButton_] button[name='submit.addToCart']:is(:focus,:focus-visible,:active){outline:none!important;outline-color:transparent!important;box-shadow:none!important;}#checkoutDisplayPage .checkout-byg-mobile-container [class*=_denseGridAxSpotAtcButton_] .a-icon-small-add{filter:brightness(0) invert(1)!important;-webkit-filter:brightness(0) invert(1)!important;opacity:1!important;}")
S_golden=S_golden.replace(
    "#checkoutDisplayPage .checkout-byg-mobile-container .a-stepper-expanding-fieldset{background:transparent!important;border:0!important;box-shadow:none!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}#checkoutDisplayPage .checkout-byg-mobile-container .a-stepper-inner-container{background:#303335!important;border:1px solid #747a7c!important;border-color:#747a7c!important;outline-color:#747a7c!important;box-shadow:none!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}#checkoutDisplayPage .checkout-byg-mobile-container .a-stepper-controls,#checkoutDisplayPage .checkout-byg-mobile-container .a-stepper-controls :is(button,div,span){background-color:transparent!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}#checkoutDisplayPage .checkout-byg-mobile-container .a-stepper-controls :is(.a-icon-small-trash,.a-icon-small-add,.a-icon-small-remove,.a-icon-small-subtract){filter:brightness(0) invert(1)!important;-webkit-filter:brightness(0) invert(1)!important;opacity:1!important;}",
    "#checkoutDisplayPage .checkout-byg-mobile-container .byg-dense-grid-atc-container .a-stepper-expanding-fieldset{background:transparent!important;border:0!important;box-shadow:none!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}#checkoutDisplayPage .checkout-byg-mobile-container .byg-dense-grid-atc-container .a-stepper-inner-container{background:#303335!important;border:1px solid #747a7c!important;border-color:#747a7c!important;outline-color:#747a7c!important;box-shadow:none!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}#checkoutDisplayPage .checkout-byg-mobile-container .byg-dense-grid-atc-container .a-stepper-controls,#checkoutDisplayPage .checkout-byg-mobile-container .byg-dense-grid-atc-container .a-stepper-controls :is(button,div,span){background-color:transparent!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}#checkoutDisplayPage .checkout-byg-mobile-container .byg-dense-grid-atc-container .a-stepper-controls :is(.a-icon-small-trash,.a-icon-small-add,.a-icon-small-remove,.a-icon-small-subtract){filter:brightness(0) invert(1)!important;-webkit-filter:brightness(0) invert(1)!important;opacity:1!important;}")
# v7.417/v7.418 approved shared-floor deltas are normalized away for the v7.386 semantic golden.
S_golden=S_golden.replace('if(!child)put(\'ad7418-switch-outline-clean\',\\"[role=switch] [data-testid=outline-outer],[role=switch] [data-testid=outline-inner]{border:0!important;border-color:transparent!important;outline:0!important;outline-color:transparent!important;box-shadow:none!important;}\\");','').replace('.cards_carousel_widget-sug-container-top .cards_carousel_widget-sug-column>:is(img,picture,[class*=cards_carousel_widget-sug-im])+*:not(:has(img,picture,source,[class*=cards_carousel_widget-sug-im])),.cards_carousel_widget-sug-container-top .cards_carousel_widget-sug-column>:has(>:is(img,picture,source,[class*=cards_carousel_widget-sug-im]))+*:not(:has(img,picture,source,[class*=cards_carousel_widget-sug-im])),.cards_carousel_widget-sug-container-top .cards_carousel_widget-sug-column>*:last-child:not(:has(img,picture,source,[class*=cards_carousel_widget-sug-im])){background:#000!important;background-color:#000!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;border-color:#494d4d!important;box-shadow:none!important;}','')
_m1='        // v7.389 FULL probe:'
_m2='        // v7.373 FULL r1/r2:'
if _m1 in S_golden:
    a=S_golden.index(_m1); b=S_golden.index(_m2,a)
    S_golden=S_golden[:a]+S_golden[b:]
# v7.402 adds two later probe-scoped Place Your Order/pickup floor rules outside the
# v7.389-v7.398 append span. Strip that exact documented block before comparing to v7.386.
_v402a='        // v7.402 FULL/transition reconciliation (23:17):'
_v402b='        // Place-order buttons.'
if _v402a in S_golden:
    a=S_golden.index(_v402a); b=S_golden.index(_v402b,a)
    S_golden=S_golden[:a]+S_golden[b:]
S_golden=S_golden.replace(",#checkoutDisplayPage #checkout-maple-upsell .maple-banner__image img","")
S_golden=S_golden.replace("#checkoutDisplayPage :is([data-testid='selected-primary-pm-card'],[data-testid='unselected-primary-pm-card']) [data-testid='image']{filter:brightness(%.3f)!important;-webkit-filter:brightness(%.3f)!important;}","").replace("#checkoutDisplayPage :is([data-testid='selected-balance-pm-giftcard'],[data-testid='unselected-balance-pm-giftcard']) [data-testid='art']{filter:brightness(%.3f)!important;-webkit-filter:brightness(%.3f)!important;}","")
S_golden=S_golden.replace("#bolt-widget-amazon_us_checkout_generic_mobile #bolt-widget-map canvas#Microsoft\\\\.Maps\\\\.Imagery\\\\.LiteRoad{filter:brightness(%.3f)!important;-webkit-filter:brightness(%.3f)!important;}","")
for name,expected in golden['programs'].items():
    assert digest(payload(S_golden,name))==expected, name+' changed beyond the approved CSS shorthand compaction / v7.389-v7.390 scoped append'
# Expand comma lists without splitting inside quotes, attributes or pseudo-classes.
def selectors(s):
    out=[];start=0;quote=None;escape=False;depth=0
    for i,c in enumerate(s):
        if quote:
            if escape:escape=False
            elif c=='\\':escape=True
            elif c==quote:quote=None
        elif c in ('"',"'"):quote=c
        elif c in '([':depth+=1
        elif c in ')]':depth-=1
        elif c==',' and depth==0:out.append(s[start:i].strip());start=i+1
    out.append(s[start:].strip());return out
js=payload(A,'ADKillerSponsoredJS7384')
css=json.loads(re.search(r'textContent=("(?:\\.|[^"\\])*")',js)[1])
rules=[]
for group,body in re.findall(r'([^{}]+)\{([^{}]+)\}',css):
    group=selectors(group)
    if any(':has(' in x for x in group):assert len(group)==1,'relational rule lost isolation'
    rules.extend((sel,body) for sel in group)
assert len(rules)==golden['sponsored_selectors']==86
assert digest(json.dumps(rules,separators=(',',':')))==golden['sponsored_rules_sha256'],'sponsored scope, specificity, cascade order or declaration changed'
for name,h in golden['probe_sha256'].items():
    data=(ROOT/'src'/name).read_bytes()
    if name=='ADUniversalUIProbe7362.js.inc':data=data.replace(b"version:'7.426'",b"version:'7.386'")  # capture-version metadata only
    assert hashlib.sha256(data).hexdigest()==h, name
assert 'ADHomeFrameProbeBridgeJS7265' not in S and '__adHomeProbeReq7265' not in S
# Script sharing is bounded, maintains order, document-start timing and frame scope.
expected=[('ADCoreWebJS7271','NO','YES'),('ADKillerSponsoredJS7384','NO','NO'),('ADPriceHistoryJS7380','YES','NO'),('ADTWBJS','NO','YES'),('ADCheckoutFloorJS7369','NO','NO'),('ADCheckoutTWBJS7369','NO','YES'),('ADCheckoutBYGHydrateJS7378','YES','NO'),('ADPrivacyModeJS7117','NO','NO')]
positions=[]
for slot,(fn,main,strength) in enumerate(expected):
    token=f'ADSharedUserScript7387({slot},{fn},{main},{strength})';assert S.count(token)==1;positions.append(S.index(token))
assert positions==sorted(positions)
assert 'static WKUserScript *scripts[8]={nil}' in S
assert 'strengthDependent&&strengths[slot]!=strength' in S
assert 'injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:mainOnly' in S
remove=S[S.index('- (void)removeAllUserScripts'):S.index('- (void)removeAllContentRuleLists')]
assert remove.index('kADCoreWebUS7271,nil')<remove.index('if(gP.enabled)'), 'disabled UCC clear kept stale receipts'
assert 'lookUpContentRuleListForIdentifier:@"AmazonDarkPrivacy7118"' in S
assert '[ADTWBJS() stringByAppendingString:ADCheckoutTWBJS7369()]' in S
# Preserve Amazon's actual caches/network configuration; optional privacy blocker is unchanged in scope.
for forbidden in ['setWebsiteDataStore:','removeDataOfTypes:','removeAllCachedResponses','setCachePolicy:','setURLCache:','setProcessPool:']:
    assert forbidden not in S,forbidden
programs={'hydrate':payload(S,'ADCheckoutBYGHydrateJS7378'),'clear':payload(S,'ADTWBClearJS791'),'privacy':payload(S,'ADPrivacyModeJS7117')}
if shutil.which('node'):
    subprocess.run(['node',str(ROOT/'tests/test_v7387_runtime.cjs')],input=json.dumps(programs),text=True,check=True)
elif os.environ.get('AD_STRICT_VALIDATE')=='1':raise AssertionError('node required in CI for runtime regressions')
else:print('SKIP: Node execution unavailable on this device; strict CI enforces it')
print('PASS: v7.386 CSS semantic hashes, all 86 sponsored selectors, unchanged probe payloads, script/cache contracts')

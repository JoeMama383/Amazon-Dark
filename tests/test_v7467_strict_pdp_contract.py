from pathlib import Path
import re
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.468~pdp-ad-book-ci-reconcile' in C
assert '#define AD_VERSION "v7.468-pdp-ad-book-ci-reconcile"' in S
assert len(S.encode()) < 856000, len(S.encode())

def fn(name,next_name=None):
    a=S.index('static NSString *'+name)
    b=S.index('static NSString *'+next_name,a) if next_name else len(S)
    return S[a:b]
blocks=[
 fn('ADProductShareThemeJS7403','ADProductShareTWBJS7403'),
 fn('ADProductShareTWBJS7403','ADShareProbeSuppressJS7403'),
 fn('ADShareProbeSuppressJS7403','ADProductScrollPolishJS7404'),
 fn('ADProductScrollPolishJS7404','ADProductScrollVideoBorderJS7405'),
 fn('ADProductScrollVideoBorderJS7405','ADPDPCompletionJS7405'),
 fn('ADPDPCompletionJS7405','ADPDPCompletionTWBJS7405'),
 fn('ADPDPCompletionTWBJS7405','ADPDPSafeFrameJS7432'),
 fn('ADPDPSafeFrameJS7432','ADPDPUICompletionJS7439'),
 fn('ADPDPUICompletionJS7439','ADForcedPDPFrameThemeJS7440'),
 fn('ADForcedPDPFrameThemeJS7440','ADFrameOwnerTriggerJS7440'),
 fn('ADPDPMainResidualJS7440','ADAddressManagementJS7412'),
 fn('ADAddressManagementJS7412','ADCoreWebJS7271')]
post=''.join(blocks)
for pat in (r'background:([^;]+)!important;background-color:\1!important',
            r'background:([^;]+)!important;background-image:none!important'):
    assert not re.search(pat,post),pat
# Historical boundaries required by frozen source-contract tests.
sf=S.index('static NSString *ADPDPSafeFrameJS7432(void)')
assert sf < S.index('// v7.439:',sf) < S.index('static NSString *ADPDPUICompletionJS7439(void)',sf)
a=S.index('static NSString *ADAddressManagementJS7412(void){')
assert a < S.index('// One immutable document-start program',a) < S.index('static long gADCoreWebJSStrength7271=-1;',a)
shared=S.index('static WKUserScript *ADSharedUserScript7387')
assert S.rfind('// v7.388: WKUserScript',0,shared) > 0
# v7.464 visual behavior remains present in consolidated form.
for tok in [
 '#dp #productInfoTabExpanderHeader0>.a-expander-content-fade{background:none!important;box-shadow:none!important;opacity:0!important}',
 '#dp#dp #ape_detail_mobile-app-detail-ilm_mshop_placement :is([data-csa-c-painter=\'sb-collections-ilm-mobile\'],[class*=_c2ItY_cardWrapper_],[class*=_c2ItY_container_],[class*=_c2ItY_containerInner_]){background:#000!important;border:0!important',
 '#ad>div>div>div:has(#offsite-buy-box){background:#000!important;border-color:#494d4d!important;box-shadow:none!important}',
 'kADPDPChildUS7464','AmazonDarkPDP7464']:
    assert tok in S,tok
for h in ['## FULL — v7.468','## VIEWPORT — v7.468','## TRANSITION — v7.468']:
    assert h in CMD,h
print('PASS: v7.468 satisfies the v7.448 consolidation gate and all restored PDP source-contract boundaries')

from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.467~pdp-ad-book-strict-repair' in C
assert '#define AD_VERSION "v7.467-pdp-ad-book-strict-repair"' in S
assert len(S.encode()) < 856000
# Frozen v7.439 regression requires this exact source boundary after SafeFrame.
sf0=S.index('static NSString *ADPDPSafeFrameJS7432(void)')
m439=S.index('// v7.439:',sf0)
u=S.index('static NSString *ADPDPUICompletionJS7439(void)',sf0)
assert sf0 < m439 < u
sf=S[sf0:m439]
for tok in [':has(video):has([class*=product])',':has(video):has([data-testid*=product])','mix-blend-mode:normal!important;opacity:1!important','.a-color-link','.a-color-price','[class*=prime]','[class*=star]','[class*=rating]','[class*=deal]','[class*=coupon]']:
    assert tok in sf,tok
f=S[u:S.index('// v7.412 FULL r1',u)]
assert 'background:#000!important' in f
assert 'background:#000!important;background-color:#000!important' not in f
# Keep the other historical source slicers intact too.
a=S.index('static NSString *ADAddressManagementJS7412(void){')
assert a < S.index('// One immutable document-start program',a) < S.index('static long gADCoreWebJSStrength7271=-1;',a)
shared=S.index('static WKUserScript *ADSharedUserScript7387')
assert S.rfind('// v7.388: WKUserScript',0,shared) > 0
# v7.464 visual delivery remains present.
for tok in ['kADPDPChildUS7464','AmazonDarkPDP7464','#productInfoTabExpanderHeader0>.a-expander-content-fade','#ad>div>div>div:has(#offsite-buy-box)']:
    assert tok in S,tok
for h in ['## FULL — v7.467','## VIEWPORT — v7.467','## TRANSITION — v7.467']:
    assert h in CMD,h
print('PASS: v7.467 restores frozen PDP/source slicing anchors without changing the v7.464 visual ownership contract')

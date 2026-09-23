from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text()
assert 'Version: 7.471~pdp-four-adcard-repair' in C
assert '#define AD_VERSION "v7.471-pdp-four-adcard-repair"' in S
assert len(S.encode()) < 856000, len(S.encode())
sf0=S.index('static NSString *ADPDPSafeFrameJS7432(void)'); m439=S.index('// v7.439:',sf0); u=S.index('static NSString *ADPDPUICompletionJS7439(void)',sf0)
assert sf0 < m439 < u
sf=S[sf0:m439]
for tok in [':has(video):has([class*=product])',':has(video):has([data-testid*=product])','mix-blend-mode:normal!important;opacity:1!important','.a-color-link','.a-color-price','[class*=prime]','[class*=star]','[class*=rating]','[class*=deal]','[class*=coupon]']:
    assert tok in sf,tok
f=S[u:S.index('// v7.412 FULL r1',u)]
assert 'background:#000!important' in f
assert 'background:#000!important;background-color:#000!important' not in f
a=S.index('static NSString *ADAddressManagementJS7412(void){')
assert a < S.index('// One immutable document-start program',a) < S.index('static long gADCoreWebJSStrength7271=-1;',a)
shared=S.index('static WKUserScript *ADSharedUserScript7387'); assert S.rfind('// v7.388: WKUserScript',0,shared) > 0
assert 'ADPDPIsolatedFrameThemeJS7470' in S and '#ad [data-testid=gridContainer]{background:#000!important;border:0!important' in S
print('PASS: v7.470 retains frozen PDP/source anchors while changing only the failed delivery lane')

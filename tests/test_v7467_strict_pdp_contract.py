from pathlib import Path
import re
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.474~pdp-visible-copy-swatch' in C
assert '#define AD_VERSION "v7.474-pdp-visible-copy-swatch"' in S
assert len(S.encode()) < 856000, len(S.encode())
def fn(name,next_name=None):
    a=S.index('static NSString *'+name); b=S.index('static NSString *'+next_name,a) if next_name else len(S); return S[a:b]
blocks=[fn('ADProductShareThemeJS7403','ADProductShareTWBJS7403'),fn('ADProductShareTWBJS7403','ADShareProbeSuppressJS7403'),fn('ADShareProbeSuppressJS7403','ADProductScrollPolishJS7404'),fn('ADProductScrollPolishJS7404','ADProductScrollVideoBorderJS7405'),fn('ADProductScrollVideoBorderJS7405','ADPDPCompletionJS7405'),fn('ADPDPCompletionJS7405','ADPDPCompletionTWBJS7405'),fn('ADPDPCompletionTWBJS7405','ADPDPSafeFrameJS7432'),fn('ADPDPSafeFrameJS7432','ADPDPUICompletionJS7439'),fn('ADPDPUICompletionJS7439','ADForcedPDPFrameThemeJS7440'),fn('ADForcedPDPFrameThemeJS7440','ADFrameOwnerTriggerJS7440'),fn('ADPDPMainResidualJS7440','ADAddressManagementJS7412'),fn('ADAddressManagementJS7412','ADCoreWebJS7271')]
post=''.join(blocks)
for pat in (r'background:([^;]+)!important;background-color:\1!important',r'background:([^;]+)!important;background-image:none!important'): assert not re.search(pat,post),pat
sf=S.index('static NSString *ADPDPSafeFrameJS7432(void)'); assert sf < S.index('// v7.439:',sf) < S.index('static NSString *ADPDPUICompletionJS7439(void)',sf)
a=S.index('static NSString *ADAddressManagementJS7412(void){'); assert a < S.index('// One immutable document-start program',a) < S.index('static long gADCoreWebJSStrength7271=-1;',a)
shared=S.index('static WKUserScript *ADSharedUserScript7387'); assert S.rfind('// v7.388: WKUserScript',0,shared) > 0
g=S[S.index('static NSString *ADPDPGridCarouselFix7454'):S.index('static NSString *ADPDPCompletionJS7405')]
for tok in ['#offsite-buy-box :is([data-testid=brand-name]','[data-testid=product-description]','[data-testid=gridContainer]{background:#000!important','[data-testid^=gridRegionCarousel]{background:#000!important;border:1px solid #494d4d!important','document.adoptedStyleSheets','replaceSync(C)']: assert tok in g,tok
for bad in ('swiper-button-prev','swiper-button-next','new MutationObserver(','setInterval(','requestAnimationFrame(' ,"addEventListener('scroll'",'createTreeWalker('): assert bad not in g,bad
assert '_WKUserStyleSheet' not in S and 'ADPDPStandalonePromoteJS7472' not in S
for h in ['## FULL — v7.474','## VIEWPORT — v7.474','## TRANSITION — v7.474']: assert h in CMD,h
print('PASS: v7.473 satisfies consolidation anchors with a persistent non-recurring PDP ad survivor sheet')

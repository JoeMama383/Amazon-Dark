from pathlib import Path
import hashlib
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text(); F=(R/'src/ADUniversalUIProbe7362.frame.js.inc').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.479~timer-actionbar-edge' in C
assert '#define AD_VERSION "v7.479-timer-actionbar-edge"' in S
assert len(S.encode()) < 856000, len(S.encode())
a=S.index('static NSString *ADStandalonePaintJS7104(void){'); b=S.index('static NSString *ADTWBJS(void){',a); stand=S[a:b]
assert hashlib.sha256(stand.encode()).hexdigest()=='2734e76915bf577d60b9a012b6fee226035582aab2a499ee1c40e3a3130f7ebe'
for t in ("if(productish)return;h.setAttribute('data-ad7104-standalone','1')","var KEY='__ad7StandaloneSheet7106'",'document.adoptedStyleSheets=a.concat([sh])','data-ad7144-full-raster-frame','ad7144Classify()'): assert t in stand,t
# v7.472 proved the mature engine can be present (standalone7104=1) while the newer grid family remains white.
# v7.473 therefore extends coverage in a separate persistent sheet without mutating the frozen mature implementation.
g=S[S.index('static NSString *ADPDPGridCarouselFix7454'):S.index('static NSString *ADPDPCompletionJS7405')]
for t in ('__ad7454PDPAdSurvivor','document.adoptedStyleSheets','data-ad7473-survivor','[data-testid=gridContainer]','sp_hqp_phoneapp_shared','offsite-buy-box'): assert t in g,t
assert 'ADPDPStandalonePromoteJS7472' not in S
for bad in ('ADPDPIsolatedFrameThemeJS7470','ADPDPIsolatedFrameThemeAttach7470','kADPDPIsolatedUS7470','_WKUserStyleSheet','ADPDPUserStyleAttach7469'): assert bad not in S,bad
assert 'adopted:adopted' in F and 'survivor7473:survivor' in F
for h in ['## FULL — v7.479','## VIEWPORT — v7.479','## TRANSITION — v7.479']: assert h in CMD,h
print('PASS: v7.473 preserves the frozen mature standalone engine and adds exact hydration-surviving coverage for its uncovered PDP renderers')

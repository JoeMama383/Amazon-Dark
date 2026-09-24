from pathlib import Path
import hashlib,re
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text(); F=(R/'src/ADUniversalUIProbe7362.frame.js.inc').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.472~pdp-standalone-unification' in C
assert '#define AD_VERSION "v7.472-pdp-standalone-unification"' in S
assert len(S.encode()) < 856000, len(S.encode())
# The mature standalone implementation itself is frozen: v7.472 reuses rather than forks it.
a=S.index('static NSString *ADStandalonePaintJS7104(void){'); b=S.index('static NSString *ADTWBJS(void){',a)
stand=S[a:b]
assert hashlib.sha256(stand.encode()).hexdigest()=='2734e76915bf577d60b9a012b6fee226035582aab2a499ee1c40e3a3130f7ebe'
for t in ("if(productish)return;h.setAttribute('data-ad7104-standalone','1')","var KEY='__ad7StandaloneSheet7106'",'document.adoptedStyleSheets=a.concat([sh])','data-ad7144-full-raster-frame','ad7144Classify()'):
    assert t in stand,t
# Page-world native frame bridge runs legacy fallback first, then the promoted mature standalone contract.
f=S[S.index('static void ADForceChildFrameTheme7440'):S.index('@interface ADFrameOwnerBridge7440')]
assert '[ADForcedPDPFrameThemeJS7440() stringByAppendingString:ADPDPStandalonePromoteJS7472()]' in f
assert 'ADPageWorld7440()' in f and 'evaluateJavaScript:inFrame:inContentWorld:completionHandler:' in S
assert 'NSSelectorFromString(@"_frameTrees:")' in f and 'NSSelectorFromString(@"_frames:")' in f
# Promotion is finite/event-driven, not a watcher.
u=S[S.index('static NSString *ADPDPStandalonePromoteJS7472'):S.index('// v7.388: WKUserScript')]
for bad in ('MutationObserver','setInterval(','requestAnimationFrame(',"addEventListener('scroll'",'createTreeWalker('): assert bad not in u,bad
for t in ('data-ad7472-pdp-standalone','data-ad7472-pdp-unified','ADStandalonePaintJS7104() stringByReplacingOccurrencesOfString','__ad7472PDPStandaloneSheet'):
    assert t in u,t
# Old failed delivery lanes are not active or retained.
for bad in ('ADPDPIsolatedFrameThemeJS7470','ADPDPIsolatedFrameThemeAttach7470','kADPDPIsolatedUS7470','_WKUserStyleSheet','ADPDPUserStyleAttach7469'):
    assert bad not in S,bad
for h in ['## FULL — v7.472','## VIEWPORT — v7.472','## TRANSITION — v7.472']: assert h in CMD,h
print('PASS: v7.472 unifies probe-proven PDP ad frames with the frozen mature standalone engine in the page world')

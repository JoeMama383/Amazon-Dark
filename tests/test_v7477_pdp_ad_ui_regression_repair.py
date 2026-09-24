from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text(); U=(R/'src/ADUniversalUIProbe7362.js.inc').read_text(); V=(R/'src/ADUIProbeViewportSample7449.js.inc').read_text(); P=(R/'src/ADPDPMainStream7451.js.inc').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.477~pdp-ad-ui-repair' in C
assert '#define AD_VERSION "v7.477-pdp-ad-ui-repair"' in S
assert len(S.encode()) < 856000, len(S.encode())
g=S[S.index('static NSString *ADPDPGridCarouselFix7454'):S.index('static NSString *ADPDPCompletionJS7405')]
# Top compact/offsite card is restored to the last working v7.474 boundary; never black-paint the full absolute overlay.
assert '#ad #absoluteComponents' not in g
for t in ('renderer-factory-ad-container]:has(#offsite-buy-box)>div:first-child','[data-testid=brand-name]','[data-testid=product-description]','button[data-testid=sponsored-container]'):
    assert t in g,t
# Medium 414x125 family is isolated by its exact proven renderer, with one gray rounded border and semantic sprite exclusions.
for t in ('[data-testid=modern-414x125-layout-container]','border:1px solid #3b4043!important','[data-testid=main-content]:has([data-testid=modern-414x125-layout-container])','[data-testid=prime-badge]','[data-testid=star]'):
    assert t in g,t
# Wrong mshop-nav geometry experiment is gone; that was not the Top/Details/Explore/Reviews row.
r=S[S.index('static NSString *ADPDPProbeBackedFixesJS7458'):S.index('static NSString *ADCoreWebJS7271')]
assert '#nav-subnav .mshop-subnav-link{display:flex!important' not in r
assert '#nav-subnav #mshop-subnav-scrollable{border-bottom:1px solid #494d4d!important}' in r
# Bottom-bar fix uses the exact probe evidence: ANX border plus 30-70x<=6 top indicator only.
for t in ('isEqualToString:@"ANXTabBarView"','v.layer.borderWidth=0','f.size.height<=6','f.size.width>=30','f.size.width<=70','f.origin.y<=1'):
    assert t in S,t
# Production geometry repair is now exact-owner and sibling-derived: copy the current sibling tab's
# computed font/line-height/padding/transform/height instead of hardcoding guessed pixels.
for t in ("getElementById('btfSubNavTopTab')","getElementById('btf-sub-nav-top-navigation-bar')","['fontSize','fontWeight','lineHeight','paddingTop','paddingBottom','transform','display']","z.height=e.offsetHeight+'px'","addEventListener('pageshow',q)"):
    assert t in r,t
# Probe now explicitly captures the actual btf sticky row and its descendant font/rect geometry.
for x in (U,V,P):
    assert 'btf-sub-nav-top-navigation-bar' in x
    assert 'btfNav7477' in x
assert 'querySelectorAll' not in V and 'createTreeWalker' not in V
for h in ('## FULL — v7.477','## VIEWPORT — v7.477','## TRANSITION — v7.477'): assert h in CMD
print('PASS: v7.477 restores the working top ad, isolates the proven 414x125 medium family, fixes exact bottom-bar lines, sibling-normalizes the real PDP Top tab, and instruments that row')

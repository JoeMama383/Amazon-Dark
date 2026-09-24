from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text(); CMD=(R/'COMMANDS.md').read_text(); UI=(R/'scripts/ui-probe.sh').read_text(); SK=(R/'scripts/skeleton-probe.sh').read_text()
assert 'Version: 7.475~pdp-offsite-nav-separators' in C
assert '#define AD_VERSION "v7.475-pdp-offsite-nav-separators"' in S
assert 'VER=7.475' in UI and 'AD_PROBE_VERSION=7.475' in SK and 'AD_PROBE_NAME=AmazonDark-v7.475' in SK
assert len(S.encode()) < 856000, len(S.encode())
g=S[S.index('static NSString *ADPDPGridCarouselFix7454'):S.index('static NSString *ADPDPCompletionJS7405')]
for t in ('#ad #absoluteComponents>div>div',
          'html body #offsite-buy-box{border:1px solid #494d4d!important;border-radius:10px!important;overflow:hidden!important}',
          '[data-testid=ratings-review-count]'):
    assert t in g,t
r=S[S.index('static NSString *ADPDPProbeBackedFixesJS7458'):S.index('static NSString *ADCoreWebJS7271')]
for t in ('#nav-subnav #mshop-subnav-scrollable{border-bottom:1px solid #494d4d!important;display:flex!important;align-items:stretch!important}',
          '#nav-subnav .mshop-subnav-link{display:flex!important;align-items:center!important;justify-content:center!important;min-height:44px!important;line-height:1.2!important}'):
    assert t in r,t
for t in ('static void ADHideThinBarHairlines7475(UIView *v){','%hook ANXTabBarView','%hook UITabBar', 'ADHideThinBarHairlines7475(v);', '- (void)layoutSubviews {'):
    assert t in S,t
for h in ['## FULL — v7.475','## VIEWPORT — v7.475','## TRANSITION — v7.475']:
    assert h in CMD,h
print('PASS: v7.475 hardens offsite standalone wrappers, normalizes PDP subnav link geometry, and hides thin bottom-bar hairlines')

from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text(); CMD=(R/'COMMANDS.md').read_text(); UI=(R/'scripts/ui-probe.sh').read_text(); SK=(R/'scripts/skeleton-probe.sh').read_text()
assert 'Version: 7.479~timer-actionbar-edge' in C
assert '#define AD_VERSION "v7.479-timer-actionbar-edge"' in S
assert 'VER=7.479' in UI and 'AD_PROBE_VERSION=7.479' in SK and 'AD_PROBE_NAME=AmazonDark-v7.479' in SK
assert len(S.encode()) < 856000, len(S.encode())
# Keep the native bar lifecycle ownership introduced in the v7.475 line, while later correction narrows its geometry.
for t in ('static void ADHideThinBarHairlines7475(UIView *v){','%hook ANXTabBarView','%hook UITabBar','ADHideThinBarHairlines7475(v);','- (void)layoutSubviews {'):
    assert t in S,t
# v7.478 intentionally retires the v7.475 broad offsite wrapper and wrong mshop geometry experiments.
g=S[S.index('static NSString *ADPDPGridCarouselFix7454'):S.index('static NSString *ADPDPCompletionJS7405')]
assert '#ad #absoluteComponents' not in g
assert '#nav-subnav .mshop-subnav-link{display:flex!important' not in S
for h in ('## FULL — v7.479','## VIEWPORT — v7.479','## TRANSITION — v7.479'): assert h in CMD
print('PASS: v7.478 retains v7.475 lifecycle ownership while retiring its two probe-disproven broad selectors')

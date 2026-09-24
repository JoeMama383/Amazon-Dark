from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text(); U=(R/'src/ADUniversalUIProbe7362.js.inc').read_text(); V=(R/'src/ADUIProbeViewportSample7449.js.inc').read_text(); P=(R/'src/ADPDPMainStream7451.js.inc').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.482~pdp-immersive-review-profile-theme' in C
assert '#define AD_VERSION "v7.482-pdp-immersive-review-profile-theme"' in S
assert len(S.encode()) < 856000, len(S.encode())
g=S[S.index('static NSString *ADPDPGridCarouselFix7454'):S.index('static NSString *ADPDPCompletionJS7405')]
# Keep v7.477's exact top/offsite ownership and isolated 414x125 renderer contract.
assert '#ad #absoluteComponents' not in g
for t in ('renderer-factory-ad-container]:has(#offsite-buy-box)>div:first-child','[data-testid=modern-414x125-layout-container]','border:1px solid #3b4043!important'):
    assert t in g,t
# v7.478 root-cause correction: the z=100 inner layer may not be an opaque cover.
assert '#sp_hqp_phoneapp_shared_inner{background:transparent!important;box-shadow:none!important}' in g
assert '#sp_hqp_phoneapp_shared_inner{background-color:#000' not in g
r=S[S.index('static NSString *ADPDPProbeBackedFixesJS7458'):S.index('static NSString *ADCoreWebJS7271')]
# The failed v7.477 outer-anchor geometry copier is gone; only the unique inner markup is normalized.
assert "var q=function(){var t=d.getElementById('btfSubNavTopTab')" not in r
for t in ('#btfSubNavTopTab .top-tab-content','#btfSubNavTopTab .a-icon-section-collapse{display:none!important}','#btfSubNavTopTab .a-size-mini{font:inherit!important}'):
    assert t in r,t
# Probe coverage for the sticky row remains available for device verification.
for x in (U,V,P):
    assert 'btf-sub-nav-top-navigation-bar' in x
    assert 'btfNav7477' in x
assert 'querySelectorAll' not in V and 'createTreeWalker' not in V
for h in ('## FULL — v7.482','## VIEWPORT — v7.482','## TRANSITION — v7.482'): assert h in CMD
print('PASS: v7.478 preserves v7.477 exact PDP ownership while correcting its opaque medium-ad overlay and failed outer Top-tab geometry strategy')

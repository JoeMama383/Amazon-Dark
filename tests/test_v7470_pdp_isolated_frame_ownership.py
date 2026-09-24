from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); F=(R/'src/ADUniversalUIProbe7362.frame.js.inc').read_text(); C=(R/'layout/DEBIAN/control').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.472~pdp-standalone-unification' in C
assert '#define AD_VERSION "v7.472-pdp-standalone-unification"' in S
assert len(S.encode()) < 856000, len(S.encode())
# The v7.470 diagnostic finding is retained, but its isolated-world production lane is retired in v7.472.
for bad in ('ADPDPIsolatedFrameThemeJS7470','ADPDPIsolatedFrameThemeAttach7470','kADPDPIsolatedUS7470'):
    assert bad not in S,bad
# Book-details fix discovered by that probe remains exact and active in the normal PDP program.
m=S[S.index('static NSString *ADPDPProbeBackedFixesJS7458'):S.index('static NSString *ADCoreWebJS7271')]
for tok in ('.putb-read-more-primary-view::before','[id^=putb-read-more-primary-view-][id$=-product-details-card_primary-view]::before','content:none!important;display:none!important;background:none!important;box-shadow:none!important','.putb-main-text :is(.a-size-small,.a-text-bold){color:#fff!important'):
    assert tok in m,tok
# Probe now reports the actual page-world standalone marker and v7.472 completion marker.
assert "theme7472:(document.documentElement&&document.documentElement.getAttribute('data-ad7472-pdp-unified'))||''" in F
assert "standalone7104:(document.documentElement&&document.documentElement.getAttribute('data-ad7104-standalone'))||''" in F
assert '_WKUserStyleSheet' not in S
for h in ['## FULL — v7.472','## VIEWPORT — v7.472','## TRANSITION — v7.472']: assert h in CMD,h
print('PASS: v7.472 retains the actual PUTB fade fix while replacing the failed isolated-world ad lane')

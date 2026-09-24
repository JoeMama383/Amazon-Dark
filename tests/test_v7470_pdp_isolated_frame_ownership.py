from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); F=(R/'src/ADUniversalUIProbe7362.frame.js.inc').read_text(); C=(R/'layout/DEBIAN/control').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.476~pdp-offsite-ci-repair' in C
assert '#define AD_VERSION "v7.476-pdp-offsite-ci-repair"' in S
assert len(S.encode()) < 856000, len(S.encode())
for bad in ('ADPDPIsolatedFrameThemeJS7470','ADPDPIsolatedFrameThemeAttach7470','kADPDPIsolatedUS7470'): assert bad not in S,bad
m=S[S.index('static NSString *ADPDPProbeBackedFixesJS7458'):S.index('static NSString *ADCoreWebJS7271')]
for tok in ('.putb-read-more-primary-view::before','[id^=putb-read-more-primary-view-][id$=-product-details-card_primary-view]::before','content:none!important;display:none!important;background:none!important;box-shadow:none!important','.putb-main-text :is(.a-size-small,.a-text-bold){color:#fff!important'): assert tok in m,tok
assert "survivor7473:(document.documentElement&&document.documentElement.getAttribute('data-ad7473-survivor'))||''" in F
assert "standalone7104:(document.documentElement&&document.documentElement.getAttribute('data-ad7104-standalone'))||''" in F
for tok in ['document.adoptedStyleSheets','adopted:adopted','survivor7473:survivor']: assert tok in F,tok
assert '_WKUserStyleSheet' not in S
for h in ['## FULL — v7.476','## VIEWPORT — v7.476','## TRANSITION — v7.476']: assert h in CMD,h
print('PASS: v7.473 retains the actual PUTB fade fix and expands frame evidence to adopted survivor sheets')

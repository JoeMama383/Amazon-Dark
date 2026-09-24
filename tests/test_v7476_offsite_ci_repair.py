from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text(); UI=(R/'scripts/ui-probe.sh').read_text(); SK=(R/'scripts/skeleton-probe.sh').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.476~pdp-offsite-ci-repair' in C
assert '#define AD_VERSION "v7.476-pdp-offsite-ci-repair"' in S
assert 'VER=7.476' in UI and 'AD_PROBE_VERSION=7.476' in SK and 'AD_PROBE_NAME=AmazonDark-v7.476' in SK
assert len(S.encode()) < 856000, len(S.encode())
block=S.split('static NSString *ADProductScrollVideoBorderJS7405(void){',1)[1].split('static NSString *ADPDPCompletionJS7405',1)[0]
assert 'overflow:hidden!important' not in block
assert 'html body #offsite-buy-box{border:1px solid #494d4d!important;border-radius:10px!important}' in block
assert '#ad #absoluteComponents>div>div' in block
assert 'ADHideThinBarHairlines7475' in S
assert '#nav-subnav .mshop-subnav-link{display:flex!important;align-items:center!important;justify-content:center!important;min-height:44px!important;line-height:1.2!important}' in S
assert 'AmazonDark-v7.476-pdp-offsite-ci-repair-source.zip' in CMD
for h in ('## FULL — v7.476','## VIEWPORT — v7.476','## TRANSITION — v7.476'): assert h in CMD
print('PASS: v7.476 removes the forbidden offsite overflow clipping while retaining the v7.475 UI ownership')

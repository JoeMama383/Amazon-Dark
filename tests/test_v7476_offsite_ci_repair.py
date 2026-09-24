from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text(); UI=(R/'scripts/ui-probe.sh').read_text(); SK=(R/'scripts/skeleton-probe.sh').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.479~timer-actionbar-edge' in C
assert '#define AD_VERSION "v7.479-timer-actionbar-edge"' in S
assert 'VER=7.479' in UI and 'AD_PROBE_VERSION=7.479' in SK and 'AD_PROBE_NAME=AmazonDark-v7.479' in SK
assert len(S.encode()) < 856000, len(S.encode())
block=S.split('static NSString *ADProductScrollVideoBorderJS7405(void){',1)[1].split('static NSString *ADPDPCompletionJS7405',1)[0]
assert 'overflow:hidden!important' not in block
# The strict-CI clipping fix remains, but the later functional correction also removes the broad absoluteComponents painter.
assert '#ad #absoluteComponents' not in block
assert 'renderer-factory-ad-container]:has(#offsite-buy-box)>div:first-child' in block
assert 'AmazonDark-v7.479-timer-actionbar-edge-source.zip' in CMD
for h in ('## FULL — v7.479','## VIEWPORT — v7.479','## TRANSITION — v7.479'): assert h in CMD
print('PASS: v7.478 retains the v7.476 no-clipping contract while restoring the working top-offsite ownership boundary')

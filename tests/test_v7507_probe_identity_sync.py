from pathlib import Path
R=Path(__file__).resolve().parents[1]
H=(R/'src/ADSkeletonProbe7339.h').read_text()
U=(R/'src/ADUniversalUIProbe7362.inc').read_text()
SH=(R/'scripts/skeleton-probe.sh').read_text()
UI=(R/'scripts/ui-probe.sh').read_text()
SB=(R/'src/AmazonDarkSB.xm').read_text()
C=(R/'layout/DEBIAN/control').read_text()
assert 'Version: 7.507~probe-identity-sync-repair' in C
assert 'AmazonDark-v7.507-probe.arm' in H
assert 'AmazonDark-v7.507-probe-status.json' in H
assert 'AmazonDark-v7.507-skeleton-%@.jsonl' in H
assert 'AmazonDark-v7.507-ui-viewport.arm' in U
assert 'AmazonDark-v7.507-ui-full.state' in U
assert 'AmazonDark-v7.507-ui-viewport.state' in U
assert 'AmazonDark-v7.507-%@-%@-r%lu.txt' in U
assert 'AD_PROBE_VERSION=7.507' in SH
assert 'AD_PROBE_NAME=AmazonDark-v7.507' in SH
assert 'case "$AD_PROBE_INSTALLED" in 7.507~*)' in SH
assert 'VER=7.507' in UI
assert 'AmazonDark-v7.507-launch-sb-probe.txt' in SB
for rel in ('src/ADSkeletonProbe7339.h','src/ADUniversalUIProbe7362.inc','scripts/skeleton-probe.sh','scripts/ui-probe.sh'):
    s=(R/rel).read_text()
    assert '7.505' not in s, (rel,'7.505')
    assert '7.506' not in s, (rel,'7.506')
print('PASS: v7.507 synchronizes every active probe arm/status/state/export/package-gate identity')

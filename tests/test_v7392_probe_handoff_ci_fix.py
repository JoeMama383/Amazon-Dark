from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'scripts/skeleton-probe.sh').read_text()
T=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
U=(ROOT/'scripts/ui-probe.sh').read_text()
H=(ROOT/'src/ADSkeletonProbe7339.h').read_text()
INC=(ROOT/'src/ADUniversalUIProbe7362.inc').read_text()
SB=(ROOT/'src/AmazonDarkSB.xm').read_text()

assert 'Version: 7.411~permission-firstpaint-owner-fix' in C
assert '#define AD_VERSION "v7.411-permission-firstpaint-owner-fix"' in T
assert 'AD_PROBE_VERSION=7.411' in S and 'AD_PROBE_CUR=${AD_PROBE_VERSION#7.}' in S and 'AD_PROBE_NAME=AmazonDark-v7.411' in S
assert 'VER=7.411' in U and 'CUR=${VER#7.}' in U
assert '"$CONTAINERS"/*/Documents/AmazonDark-v7.*-probe-status.json' in U
assert 'rv=${r##*/}; rv=${rv#AmazonDark-v7.}; rv=${rv%-probe-status.json}' in U
assert '[ "$rv" -ge 344 ]' in U and '[ "$rv" -le "$CUR" ]' in U
assert 'version"[[:space:]]*:[[:space:]]*"v7[.]' in U and '$rv' in U
assert 'AmazonDark-v7.411-probe.arm' in H and 'AmazonDark-v7.411-probe-status.json' in H
assert 'AMAZONDARK v7.411 UNIVERSAL' in INC and 'AmazonDark-v7.411-ui-viewport.arm' in INC
assert 'AmazonDark-v7.411-launch-sb-probe.txt' in SB

# The v7.391 failure was caused by duplicated explicit receipt-version lists drifting during a bump.
# Discovery/report/export now share globbed status families; payload version must agree with filename.
assert '"$AD_PROBE_CONTAINERS"/*/Documents/AmazonDark-v7.*-probe-status.json' in S
assert 'AD_PROBE_RECEIPT_VER=${AD_PROBE_RECEIPT##*/}' in S
assert 'AD_PROBE_RECEIPT_VER=${AD_PROBE_RECEIPT_VER#AmazonDark-v7.}' in S
assert 'AD_PROBE_RECEIPT_VER=${AD_PROBE_RECEIPT_VER%-probe-status.json}' in S
assert '[ "$AD_PROBE_RECEIPT_VER" -ge 344 ]' in S
assert '[ "$AD_PROBE_RECEIPT_VER" -le "$AD_PROBE_CUR" ]' in S
assert '"v7[.]\'"$AD_PROBE_RECEIPT_VER"\'-\'' in S
assert '"$AD_PROBE_DIR"/AmazonDark-v7.*-probe-status.json' in S

# No stale explicit candidate list may reappear for current/recent releases.
discovery=S.split('# Read the current receipt or verified recent receipts left during upgrade.',1)[1].split('ad_report() {',1)[0]
for v in ('7.392','7.391','7.390','7.389'):
    assert f'AmazonDark-v{v}-probe-status.json' not in discovery

# This release does not add recurring production machinery.
for bad in ('new MutationObserver(', 'setInterval(', 'requestAnimationFrame('):
    assert bad not in T
print('PASS: v7.392 removes version-list drift from skeleton receipt handoff while preserving v7.391 production theming architecture')

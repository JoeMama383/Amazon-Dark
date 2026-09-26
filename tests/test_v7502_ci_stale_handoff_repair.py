from pathlib import Path
import json
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text()
J=''.join(json.loads(line) for line in (R/'src/ADNewMenus7482.js.inc').read_text().splitlines() if line.strip())
C=(R/'layout/DEBIAN/control').read_text()
V=(R/'scripts/validate.sh').read_text()
CMD=(R/'COMMANDS.md').read_text()
UI=(R/'scripts/ui-probe.sh').read_text()
SK=(R/'scripts/skeleton-probe.sh').read_text()
assert 'Version: 7.502~ci-stale-handoff-repair' in C
assert '#define AD_VERSION "v7.502-ci-stale-handoff-repair"' in T
assert 'VER=7.502' in UI
assert 'AD_PROBE_VERSION=7.502' in SK
assert 'AmazonDark-v7.502-ci-stale-handoff-repair-source.zip' in CMD
assert 'AD_STRICT_VALIDATE=0 sh scripts/validate.sh' in CMD
assert not (R/'tests/test_v7500_ci_repair.py').exists()
assert 'tests/test_v7500_ci_repair.py' in V
# Retain the v7.501 UI behavior that superseded v7.500's incompatible .58 overlay assertions.
root='section.your-orders-mobile-content-container.aok-relative.js-yo-container'
assert root+' [class*="_timely-reminders-information-tile_style_tileContainer"]::before{' in J
assert 'content:none!important;display:none!important;background:none!important;box-shadow:none!important;' in J
assert root+' [class*="_timely-reminders-information-tile_style_imageContainer"]::after{' in J
assert 'background-color:inherit!important;background-blend-mode:normal!important;background-clip:padding-box!important;' in J
assert root+' .search-bar__open-filter-link{' in J
assert '-webkit-tap-highlight-color:transparent!important;' in J
assert 'static NSString *ADPDPAdImageBackgroundJS7501(void)' in T
assert '#include "ADPDPAdImageBackground7501.js.inc"' in T
# No new steady-state traversal machinery.
for bad in ('MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in J, bad
print('PASS: v7.502 removes the superseded v7.500 CI contract, stale-gates it, and retains the v7.501 UI fixes')

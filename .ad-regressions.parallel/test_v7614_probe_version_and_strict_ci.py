"""v7.614: all three opt-in probe helpers and emitted diagnostics must follow the package version."""
from pathlib import Path
import re
import subprocess

R=Path(__file__).resolve().parents[1]
control=(R/'layout/DEBIAN/control').read_text()
version=re.search(r'^Version: (7\.\d+)~([\w.-]+)$',control,re.M)
assert version, 'package version is malformed'
ver,slug=version.groups()
tag='v'+ver+'-'+slug

T=(R/'src/Tweak.xm').read_text()
assert '#define AD_VERSION "'+tag+'"' in T
ui=(R/'scripts/ui-probe.sh').read_text()
sk=(R/'scripts/skeleton-probe.sh').read_text()
perf=(R/'scripts/performance-probe.sh').read_text()
assert re.search(r'^VER='+re.escape(ver)+r'$',ui,re.M)
assert re.search(r'^AD_PROBE_VERSION='+re.escape(ver)+r'$',sk,re.M)
assert re.search(r'^AD_PROBE_NAME=AmazonDark-v'+re.escape(ver)+r'$',sk,re.M)
assert re.search(r'^VER='+re.escape(ver)+r'$',perf,re.M)
assert 'in '+ver+'~*' in sk
# The prior performance helper stopped accepting probe receipts after 7.597.
assert '[ "$rv" -le "${VER#7.}" ]' in perf
assert '-le 597' not in perf
for name,needle in {
    'src/ADUniversalUIProbe7362.inc':'AMAZONDARK v'+ver+' UNIVERSAL',
    'src/ADUniversalUIProbe7362.js.inc':"version:'"+ver+"'",
    'src/ADUniversalUIProbe7362.frame.js.inc':"version:'"+ver+"'",
    'src/ADUIProbeViewportSample7449.js.inc':"version:'"+ver+"'",
    'src/ADPDPMainStream7451.js.inc':"version:'"+ver+"'",
    'src/AmazonDarkSB.xm':'AmazonDark-v'+ver+'-launch-sb-probe.txt',
    'src/ADPerformance7596.inc':'AmazonDark-v'+ver+'-performance',
    'src/ADSkeletonProbe7339.h':'AmazonDark-v'+ver+'-probe.arm',
}.items():
    assert needle in (R/name).read_text(),name
commands=(R/'COMMANDS.md').read_text()
for label in ('FULL','VIEWPORT','TRANSITION'):
    assert '## '+label+' — v'+ver in commands
for need in ('AmazonDark-v'+ver+'-'+slug+'-source.zip',
             'AD_STRICT_VALIDATE=0 sh scripts/validate.sh',
             'git push origin main','ui-probe.sh export full','ui-probe.sh arm',
             'ui-probe.sh export viewport','skeleton-probe.sh arm transition',
             'skeleton-probe.sh export'):
    assert need in commands,need
for script in ('ui-probe.sh','skeleton-probe.sh','performance-probe.sh'):
    subprocess.run(['sh','-n',str(R/'scripts'/script)],check=True)
validate=(R/'scripts/validate.sh').read_text()
for need in ('require_literal scripts/ui-probe.sh "VER=$cur_version"',
             'require_literal scripts/performance-probe.sh "VER=$cur_version"',
             'require_literal scripts/skeleton-probe.sh "AD_PROBE_VERSION=$cur_version"',
             'require_literal src/AmazonDarkSB.xm'):
    assert need in validate,need
# Every regression created since the most recent v7.605 device probe remains in CI.
for minor in range(606,614):
    assert list((R/'tests').glob('test_v7'+str(minor)+'_*.py')),minor
print('PASS: current version synchronized in package, 3 probe helpers, native/web diagnostics, command handoff and CI gate; post-probe regressions present')

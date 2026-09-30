from pathlib import Path
R=Path(__file__).resolve().parents[1]
C=(R/'layout/DEBIAN/control').read_text()
T=(R/'src/Tweak.xm').read_text()
CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.531~interests-regression-handoff-repair' in C
assert '#define AD_VERSION "v7.531-interests-regression-handoff-repair"' in T
assert 'AmazonDark-v7.531-interests-regression-handoff-repair-source.zip' in CMD
assert 'sh scripts/validate.sh' in CMD
for good in ('cd /var/mobile/Amazon-Dark-phone','ui-probe.sh export full','ui-probe.sh arm','ui-probe.sh export viewport','skeleton-probe.sh arm transition','skeleton-probe.sh export','git push origin main'):
    assert good in CMD, good
for bad in ('git init','rm -rf .git','git push -uf','ui-probe.sh full','viewport-arm','viewport-export'):
    assert bad not in CMD, bad
print('PASS: v7.531 synchronizes the source ZIP identity and preserves the frozen AmazonDark handoff contract')

from pathlib import Path
R=Path(__file__).resolve().parents[1]
C=(R/'layout/DEBIAN/control').read_text()
T=(R/'src/Tweak.xm').read_text()
CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.619~handoff-regression-repair' in C
assert '#define AD_VERSION "v7.619-handoff-regression-repair"' in T
for good in [
    'cd /var/mobile/Amazon-Dark-phone',
    'cp -a "$STAGE/." .',
    'AD_STRICT_VALIDATE=0 sh scripts/validate.sh',
    'git push origin main',
    'ui-probe.sh export full',
    'ui-probe.sh arm',
    'ui-probe.sh export viewport',
    'skeleton-probe.sh arm transition',
    'skeleton-probe.sh export',
]: assert good in CMD, good
for bad in ['git init','rm -rf .git','git push -uf','ui-probe.sh full','ui-probe.sh viewport-arm','ui-probe.sh viewport-export']:
    assert bad not in CMD, bad
print('PASS: frozen existing-clone push workflow and FULL/VIEWPORT/TRANSITION handoff contract remain intact under v7.619')

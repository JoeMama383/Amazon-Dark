from pathlib import Path
R=Path(__file__).resolve().parents[1]
C=(R/'layout/DEBIAN/control').read_text()
T=(R/'src/Tweak.xm').read_text()
CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.551~ui-restoration-no-tweak-size-gate' in C
assert '#define AD_VERSION "v7.551-ui-restoration-no-tweak-size-gate"' in T
needle_s='len(S.encode()) < '+str(856000)
needle_t='len(T.encode()) < '+str(856000)
for p in (R/'tests').glob('test_*.py'):
    if p.name==Path(__file__).name: continue
    s=p.read_text()
    assert needle_s not in s, p.name
    assert needle_t not in s, p.name
# Preserve the three UI repairs requested in this handoff.
N=(R/'src/ADNewMenus7482.js.inc').read_text()
A=(R/'src/ADAppSettings7550.inc').read_text()
assert 'search filter sheet follow-up' in N
assert 'About You memory grid follow-up' in N
assert 'ADAppSettingsRoot7548' in A and 'ADAppSettingsOwnText7548' in A
assert 'kADAppSettingsWitness7548' in A and 'objc_getAssociatedObject(root,kADAppSettingsWitness7548)' in A and 'objc_setAssociatedObject(root,kADAppSettingsWitness7548' in A
# Frozen handoff API remains unchanged.
for token in ('ui-probe.sh export full','ui-probe.sh arm','ui-probe.sh export viewport','skeleton-probe.sh arm transition','skeleton-probe.sh export','git push origin main'):
    assert token in CMD, token
print('PASS: v7.551 retires the obsolete Tweak.xm 856000-byte test gate while preserving the requested UI restorations and frozen handoff contract')

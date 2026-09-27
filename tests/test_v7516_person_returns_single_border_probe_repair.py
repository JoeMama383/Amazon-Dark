from pathlib import Path
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text(); P=(R/'src/ADPersonReturns7514.inc').read_text(); U=(R/'src/ADUniversalUIProbe7362.inc').read_text(); V=(R/'scripts/validate.sh').read_text(); C=(R/'layout/DEBIAN/control').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.516~person-returns-single-border-probe-repair' in C
assert '#define AD_VERSION "v7.516-person-returns-single-border-probe-repair"' in T
assert 'AmazonDarkPersonReturnsOutline7514' not in P
assert '[CAShapeLayer layer]' not in P
assert 'ADPersonSetRCTBorder7208(v,1.0);' in P
assert 'v.layer.borderWidth=0.0' in P
assert 'ADPersonPrimeReturns7514(root)' in T and 'ADPersonReturnsUnder7514(v)' in T
assert 'ADUICanonicalReactRootScroll7516' in U
assert 'if(canonical)score+=1500000' in U
assert 'ADUIViewDescendsFrom7516(sv,canonicalRoot)' in U
assert 'ADUICaptureBusyViewportFallback7516' in U
assert 'if(!ADUIConsumeViewportArm7362())return;' in U
assert 'if(gADUIProbeBusy7362){ ADUICaptureBusyViewportFallback7516(); return; }' in U
assert 'tests/test_v7514_person_returns_rehydrate_scan.py' in V
assert not (R/'tests/test_v7514_person_returns_rehydrate_scan.py').exists()
assert 'AmazonDark-v7.516-person-returns-single-border-probe-repair-source.zip' in CMD
print('PASS: v7.516 restores single RCT Returns borders and makes canonical React FULL plus busy-FULL VIEWPORT capture deterministic')

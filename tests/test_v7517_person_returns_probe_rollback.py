from pathlib import Path
import hashlib,re
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text(); P=(R/'src/ADPersonReturns7514.inc').read_text(); U=(R/'src/ADUniversalUIProbe7362.inc').read_text(); V=(R/'scripts/validate.sh').read_text(); C=(R/'layout/DEBIAN/control').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.517~person-returns-probe-rollback' in C
assert '#define AD_VERSION "v7.517-person-returns-probe-rollback"' in T
# Last-known-good universal probe engine restored exactly, identity aside.
norm=U.replace('v7.517','v7.X')
assert hashlib.sha256(norm.encode()).hexdigest() == '84191ab275f851536e9dd5a07bc3b902b921c56622b99011e5df6b41b0dceba0'
assert 'ADUICanonicalReactRootScroll7516' not in U
assert 'ADUICaptureBusyViewportFallback7516' not in U
# Returns: only outermost card owns a border; nested candidate wrappers are cleared.
assert 'ADPersonReturnsHasCardAncestor7517' in P
assert 'ADPersonReturnsOuterCard7517' in P
assert 'if(!ADPersonReturnsOuterCard7517(v))' in P
assert 'ADPersonSetRCTBorder7208(v,0.0);' in P
assert 'ADPersonSetRCTBorder7208(v,1.0);' in P
assert '[CAShapeLayer layer]' not in P
assert 'ADPersonPrimeReturns7514(root)' in T
assert 'ADPersonReturnsUnder7514(v)' in T
assert 'tests/test_v7516_person_returns_single_border_probe_repair.py' in V
assert not (R/'tests/test_v7516_person_returns_single_border_probe_repair.py').exists()
assert 'AmazonDark-v7.517-person-returns-probe-rollback-source.zip' in CMD
print('PASS: v7.517 restores the v7.513 universal probe engine and gives each Returns button exactly one outer RCT border')

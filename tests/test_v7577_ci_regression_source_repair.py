from pathlib import Path
import json
from payload_source import payload

R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text()
H=(R/'src/ADSkeletonProbe7339.h').read_text()
M=(R/'src/ADNewMenus7482.js.inc').read_text()
G=(R/'tests/test_v7480_build_syntax_guard.py').read_text()
C=(R/'layout/DEBIAN/control').read_text()
CMD=(R/'COMMANDS.md').read_text()

assert 'Version: 7.577~ci-regression-source-repair' in C
assert '#define AD_VERSION "v7.577-ci-regression-source-repair"' in T
assert 'AmazonDark-v7.577-ci-regression-source-repair-source.zip' in CMD

# v7.448 production performance contract: exactly one inherited querySelectorAll call in Tweak.xm.
assert T.count('querySelectorAll(') == 1
frag=payload(T,'ADDealsPriceHistoryFollowupJS7574')
assert 'querySelectorAll(' not in frag
assert "getElementsByTagName('*')" in frag
assert "getElementsByClassName(names[ni])" in frag

# Standalone Objective-C++ preflight must include every current dependency of ADPDPProbeBackedFixesJS7458.
assert "'ADDealsPriceHistoryFollowupJS7574'" in G

# Interests adopted-sheet slicing depends on this exact boundary marker remaining in the production CSS.
assert '/* v7.553 FULL r3 exact-owner search Filters sheet follow-up. */' in M
assert "end=css.indexOf('/* v7.553 FULL r3 exact-owner search Filters',start)" in M

# Historical AMI lifecycle regression normalizes this current-version source marker.
assert '// v7.577 transition expansion:' in H
print('PASS: v7.577 repairs the v7.448 performance gate, v7.480 syntax-preflight dependency source, v7.535 Interests CSS boundary, and current AMI regression marker')

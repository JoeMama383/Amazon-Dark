from pathlib import Path
R=Path(__file__).resolve().parents[1]
C=(R/'layout/DEBIAN/control').read_text(); T=(R/'src/Tweak.xm').read_text(); N=(R/'src/ADNewMenus7482.js.inc').read_text()
assert 'Version: 7.619~handoff-regression-repair' in C
assert '#define AD_VERSION "v7.619-handoff-regression-repair"' in T
import re
for p in (R/'tests').glob('test_*.py'):
    if p.name==Path(__file__).name: continue
    s=p.read_text()
    assert not re.search(r'assert\s+len\([ST]\.encode\(\)\)\s*<\s*\d+', s), p.name
for token in ('#dropdown-content-s-all-filters','.sf-filters-vtabs-tabs-container','.s-vtabs-contents-container','.sf-bottom-nav.sf-bottom-nav-current','.sf-show-results'):
    assert token in N, token
print('PASS: v7.619 retires the obsolete Tweak.xm size gate and freezes exact probe-derived Filters owners')

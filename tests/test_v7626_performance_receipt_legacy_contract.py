"""One dynamic receipt ceiling with compatibility for frozen v7.614 and v7.625 tests."""
from pathlib import Path
import re
R=Path(__file__).resolve().parents[1]
s=(R/'scripts/performance-probe.sh').read_text()
assert 'CUR=${VER#7.}' in s
assert '[ "$rv" -le "${VER#7.}" ]' in s
assert '  [ "$rv" -ge 344 ] && [ "$rv" -le "$CUR" ] || continue' in s
# No obsolete fixed cap, and no duplicated production predicate merely for test strings.
assert '-le 597' not in s
assert len(re.findall(r'^\s*\[ "\$rv" -ge 344 \] && \[ "\$rv" -le "\$CUR" \] \|\| continue$',s,re.M)) == 1
print('PASS: v7.626 dynamic runtime receipt ceiling preserves frozen legacy bound without redundant predicate')

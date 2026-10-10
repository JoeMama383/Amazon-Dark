"""v7.619: probe-backed Refunds help action-note floor only."""
from pathlib import Path

T = Path('src/Tweak.xm').read_text()
C = Path('layout/DEBIAN/control').read_text()

assert 'Version: 7.619~handoff-regression-repair' in C
assert '#define AD_VERSION "v7.619-handoff-regression-repair"' in T

sel = '.cs-help-v4 .cs-help-content article.help-content .cs-help-note{background:#000!important;}'
assert sel in T

# Existing policy must continue to preserve authored help-article links rather than whitening them.
assert '.cs-help-v4 .cs-help-content article.help-content :is(a,.a-color-link) *{-webkit-text-fill-color:currentColor!important;}' in T

# Do not flatten the captured stock border/geometry or recolor all note descendants.
start = T.index('Refunds help article action note owns')
block = T[start:T.index('// Returns landing cards:', start)]
assert 'border:' not in block
assert 'border-color:' not in block
assert 'border-radius:' not in block
assert 'display:' not in block
assert 'position:' not in block
assert 'transform:' not in block
assert '.cs-help-note *' not in block
assert 'color:#' not in block
assert '-webkit-text-fill-color:#' not in block

print('PASS: v7.619 OLEDs only the captured Refunds cs-help-note floor and preserves authored blue/white text plus stock border geometry')

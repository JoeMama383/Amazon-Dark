"""Regression for legacy v7.375/v7.439/v7.525 handoff validation contract."""
from pathlib import Path
r=Path(__file__).resolve().parents[1]
c=(r/'COMMANDS.md').read_text()
assert 'AD_STRICT_VALIDATE=0 sh scripts/validate.sh' in c
assert 'sh scripts/validate.sh' in c
assert c.index('AD_STRICT_VALIDATE=0 sh scripts/validate.sh')<c.index('git add -A')
assert 'git push origin main' in c
assert 'rm -f src/ADMenuRepair7620.js src/ADMenuRepair7620.js.inc' in c
assert '## PERFORMANCE — v7.632 ARM' in c
assert '## FULL — v7.632' in c
assert '## VIEWPORT — v7.632 ARM' in c
assert '## TRANSITION — v7.632 ARM' in c
print('PASS: v7.632 push validates, retains cleanup and separate diagnostic commands')

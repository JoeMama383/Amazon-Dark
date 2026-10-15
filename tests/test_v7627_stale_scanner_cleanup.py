# v7.634 adds one bounded Your Books existing-shadow catch-up, no recurring scanner.
"""Prevent stale overlay-only v7.619 Home-raster code leaking into scanner CI."""
from pathlib import Path
import importlib.util
import tempfile

ROOT=Path(__file__).resolve().parents[1]
AUDIT=ROOT/'scripts/performance-source-audit.py'
spec=importlib.util.spec_from_file_location('ad_perf_stale_guard_7627',AUDIT)
mod=importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
rows,groups=mod.analyze(ROOT)
prod=groups['production / combined']
assert prod['querySelectorAll'] == 9, prod
# v7.642's single bounded ID-only owner observer is covered by its own lifecycle
# regression and the production audit. Old broad scanners remain forbidden.
assert prod['MutationObserver']==1 and prod['setInterval']==0 and prod['TreeWalker']==0
assert prod['requestAnimationFrame']==0
assert not (ROOT/'src/ADMenuRepair7620.js').exists()
assert not (ROOT/'src/ADMenuRepair7620.js.inc').exists()

validator=(ROOT/'scripts/validate.sh').read_text()
assert 'for stale in src/ADMenuRepair7620.js src/ADMenuRepair7620.js.inc; do' in validator
assert 'obsolete v7.619 Home-raster module retained' in validator
commands=(ROOT/'COMMANDS.md').read_text()
assert 'rm -f src/ADMenuRepair7620.js src/ADMenuRepair7620.js.inc' in commands
assert 'git add -A' in commands

# Reproduce the precise CI count without modifying the checkout. The two orphan
# querySelectorAll calls would raise the pristine source census from 8 to 10.
with tempfile.TemporaryDirectory() as td:
    mock=Path(td)
    src=mock/'src'
    src.mkdir()
    for file in (ROOT/'src').iterdir():
        if file.is_file() and file.suffix in ('.xm','.inc','.js','.h'):
            (src/file.name).symlink_to(file)
    (src/'ADMenuRepair7620.js').write_text('''function obsoleteHome(){
  var cards=document.querySelectorAll('[class*="sponsored"]');
  cards.forEach(function(c){ c.querySelectorAll('img'); });
}''')
    _,dirty=mod.analyze(mock)
    assert dirty['production / combined']['querySelectorAll']==11, dirty
print('PASS: v7.627 discarded v7.619 raster source is explicitly removed; clean 9, ghost 11, no production recurring scanners')

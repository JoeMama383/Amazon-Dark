from pathlib import Path
R=Path(__file__).resolve().parents[1]
C=(R/'layout/DEBIAN/control').read_text()
T=(R/'src/Tweak.xm').read_text()
CSS=(R/'src/ADNewMenus7482.js.inc').read_text()
CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.619~handoff-regression-repair' in C
assert '#define AD_VERSION "v7.619-handoff-regression-repair"' in T
for token in ('_bW9ia_plus-carousel-element_1z8GB','_bW9ia_plus-container_1QjeQ','_bW9ia_plus-thumbnail-link_2gUEq','#create-prompt-link'):
    assert token in CSS, token
assert '#create-prompt-link::before' in CSS and '#create-prompt-link::after' in CSS
assert 'color:#fff!important;-webkit-text-fill-color:#fff!important;fill:#fff!important;stroke:#fff!important;' in CSS
assert 'border-color:#747a7c!important' in CSS
for good in ('ui-probe.sh export full','ui-probe.sh arm','ui-probe.sh export viewport','skeleton-probe.sh arm transition','skeleton-probe.sh export','git push origin main'):
    assert good in CMD, good
for bad in ('git init','rm -rf .git','git push -uf','ui-probe.sh full','viewport-arm','viewport-export'):
    assert bad not in CMD, bad
print('PASS: v7.619 explicitly whitens the probe-confirmed Interests plus glyph while preserving its gray ring and frozen handoff contract')

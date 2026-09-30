from pathlib import Path
import re
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text()
I=(R/'src/ADKeyboardDockGeometry7513.inc').read_text()
C=(R/'layout/DEBIAN/control').read_text()
CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.526~returns-thumbnail-taming-fix' in C
assert '#define AD_VERSION "v7.526-returns-thumbnail-taming-fix"' in S
assert '#include "ADKeyboardDockGeometry7513.inc"' in S
assert 'ADAlignKeyboardMic7513((UIKeyboardDockView *)self);' in S
assert len(S.encode()) < 856000, len(S.encode())
for token in ('UIKeyboardDockItemButton','ADDockItemImage7513','rightIcon.bounds.size.height/rightIcon.bounds.size.width','ratio<1.08','lc.y-rc.y','rightIcon.center=c'):
    assert token in I, token
# Geometry ownership is deliberately narrow: direct dock children only, right image center-Y only.
for forbidden in ('setFrame:', 'right.frame=', 'left.frame=', 'rightIcon.bounds=', 'rightIcon.transform=', 'MutationObserver(', 'setInterval(', 'requestAnimationFrame('):
    assert forbidden not in I, forbidden
assert 'c.y=target.y;rightIcon.center=c;' in I
assert 'c.x=' not in I
print('PASS: v7.526 aligns only the global keyboard dictation glyph Y-center to the sibling dock control without changing button/icon size or X geometry')

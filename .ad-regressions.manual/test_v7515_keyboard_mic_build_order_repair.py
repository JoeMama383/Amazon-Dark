from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text()
C=(R/'layout/DEBIAN/control').read_text()
CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.526~returns-thumbnail-taming-fix' in C
assert '#define AD_VERSION "v7.526-returns-thumbnail-taming-fix"' in S
inc='#include "ADKeyboardDockGeometry7513.inc"'
call='ADAlignKeyboardMic7513((UIKeyboardDockView *)self);'
assert inc in S and call in S
assert S.index(inc) < S.index('%hook UIKeyboardDockView') < S.index(call), 'geometry helper must be declared before Logos hook expansion uses it'
assert S.count(inc)==1
assert 'AmazonDark-v7.526-returns-thumbnail-taming-fix-source.zip' in CMD
print('PASS: v7.526 declares the shared keyboard mic geometry helper before UIKeyboardDockView hook compilation')

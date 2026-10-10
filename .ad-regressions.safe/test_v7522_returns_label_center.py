from pathlib import Path
import subprocess,tempfile
R=Path(__file__).resolve().parents[1]
p=(R/'src/ADPersonReturns7514.inc').read_text()
t=(R/'src/Tweak.xm').read_text()
b=p[p.index('static void ADPersonCenterReturnsText7522'):]
for s in ['ImageWithTextViewParentComponent','ImageWithTextViewTextComponent','ADPersonReturnsIdentity7521(card)','usedRectForTextContainer:tc','ensureLayoutForTextContainer:tc','toView:wrap.superview']:
 assert s in b
assert t.count('ADPersonCenterReturnsText7522(')==4
assert 'card.center=' not in b and 'card.frame=' not in b and 'wrap.bounds=' not in b
# Actual correction expression: applying twice must not accumulate translation.
expr=b[b.index('CGFloat dx='):b.index('    } @catch',b.index('CGFloat dx='))]
code="#include <cmath>\n#include <cassert>\ntypedef double CGFloat;struct CGPoint{double x,y;};struct Wrap{CGPoint center;};\nint main(){Wrap wrap={{178,35}};CGPoint wanted={146,35},actual={178,35};\n"+expr+"\nassert(fabs(wrap.center.x-146)<.001);actual.x=146;\n"+expr.replace('CGFloat dx=','dx=')+"\nassert(fabs(wrap.center.x-146)<.001);assert(wrap.center.y==35); }"
with tempfile.TemporaryDirectory() as d:
 f=Path(d)/'center.cpp';f.write_text(code);out=Path(d)/'center'
 subprocess.run(['g++','-std=c++11',str(f),'-o',str(out)],check=True)
 subprocess.run([str(out)],check=True)
print('PASS: exact Returns text glyph alignment is horizontally centered, repeat-safe, and preserves card dimensions')

from pathlib import Path
import subprocess, tempfile
R=Path(__file__).resolve().parents[1]
p=(R/'src/ADPersonReturns7514.inc').read_text()
t=(R/'src/Tweak.xm').read_text()

# Execute the shipped narrow-column geometry against the exact v7.522 r2 capture.
b=p[p.index('static BOOL ADPersonReturnsLeftOccluderGeometry7523'):p.index('static BOOL ADPersonReturnsLeftCornerOccluder7523')]
expr=b[b.index('return '):b.index(';',b.index('return '))+1]
code='''#include <cmath>\n#include <cassert>\nstruct P{double x,y;};struct S{double width,height;};struct Rect{P origin;S size;};\ndouble CGRectGetMaxY(Rect f){return f.origin.y+f.size.height;}\nbool hit(Rect f,S b){'''+expr+'''}\nint main(){S card={292,69.3};\nassert(hit({{1,1},{60,67.3}},card));       // exact r2 opaque thumbnail-column plane\nassert(!hit({{8,7.7},{48,52}},card));     // actual thumbnail/image wrapper\nassert(!hit({{1,1},{290,67.3}},card));    // v7.521 near-full inset plane\nassert(!hit({{44.4,22.3},{225,23}},card));// centered text wrapper\nassert(!hit({{1,1},{80,67.3}},card));     // too wide to be reserved column\n}\n'''
with tempfile.TemporaryDirectory() as d:
    f=Path(d)/'left.cpp'; f.write_text(code); out=Path(d)/'left'
    subprocess.run(['g++','-std=c++11',str(f),'-o',str(out)],check=True)
    subprocess.run([str(out)],check=True)

left=p[p.index('static BOOL ADPersonReturnsLeftCornerOccluder7523'):p.index('static BOOL ADPersonReturnsUnder7514')]
for token in ['v.subviews.count','ADPersonReturnsIdentity7521(n)','[card.accessibilityIdentifier hasPrefix:@"yr_item_"]','convertRect:v.bounds toView:card']:
    assert token in left, token
assert 'ADSetViewBackground7226(v,[UIColor clearColor],YES)' in left
assert '[v setNeedsDisplay];[v.layer setNeedsDisplay]' in left

# Rehydration coverage: ordinary mount/layout ownership, bounded section priming, and
# direct interception when React rewrites the fill after submenu/back or offline refresh.
owner=t[t.index('static void ADPersonOwnView7206'):t.index('static BOOL ADPersonPrimaryFont7206')]
assert 'ADPersonReturnsLeftCornerOccluder7523(v)' in owner
prime=p[p.index('static void ADPersonPrimeReturns7514'):p.index('static NSTextStorage *ADPersonTextStorage7206')]
assert 'ADPersonOwnReturnsLeftCornerOccluder7523(v)' in prime
rct=t[t.index('%hook RCTView'):t.index('%end',t.index('%hook RCTView'))]
for hook in ['didMoveToWindow','didMoveToSuperview','layoutSubviews']:
    assert '- (void)'+hook in rct and 'ADOwnReactView7226' in rct
assert 'ADPersonBuyAgainOccluder7235(v)||ADPersonReturnsOccluder7521(v)||ADPersonReturnsLeftCornerOccluder7523(v)' in rct

# Corner repair is paint-only. The v7.522 text centering remains exactly as shipped.
actual='\n'.join(x for x in left.splitlines() if not x.strip().startswith('//'))
for token in ['setBorderWidth:', 'setBorderRadius:', '.frame=', '.bounds=', '.cornerRadius=', '.mask=', '[CAShapeLayer layer]']:
    assert token not in actual, token
assert t.count('ADPersonCenterReturnsText7522(')==4
print('PASS: v7.523 clears only the exact 60pt left Returns paint plane across mount/layout/background rehydration and preserves authored geometry')

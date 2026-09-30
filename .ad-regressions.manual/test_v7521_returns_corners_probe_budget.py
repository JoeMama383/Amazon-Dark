from pathlib import Path
import subprocess, tempfile
R=Path(__file__).resolve().parents[1]
p=(R/'src/ADPersonReturns7514.inc').read_text()
t=(R/'src/Tweak.xm').read_text()
u=(R/'src/ADUniversalUIProbe7362.inc').read_text()
# Execute the shipped inset predicate against r5 geometry and negative controls.
b=p[p.index('static BOOL ADPersonReturnsOccluder7521'):p.index('static BOOL ADPersonReturnsUnder7514')]
expr=b[b.index('return f.origin.x'):b.index(';',b.index('return f.origin.x'))+1]
code='''#include <cmath>
#include <cassert>
struct P{double x,y;};struct S{double width,height;};struct Rect{P origin;S size;};
double CGRectGetMaxX(Rect f){return f.origin.x+f.size.width;}
double CGRectGetMaxY(Rect f){return f.origin.y+f.size.height;}
bool inset(Rect f,S b){'''+expr+'''}
int main(){S b={292,69.3};
assert(inset({{1,1},{290,67.3}},b));
assert(!inset({{1,23.7},{290,22}},b)); // right-hand text leaf
assert(!inset({{60,0},{230,67.3}},b)); // content column
assert(!inset({{0,0},{300,69.3}},b)); // outer spacing wrapper
assert(!inset({{-1,1},{290,67.3}},b));
}
'''
with tempfile.TemporaryDirectory() as d:
 f=Path(d)/'geometry.cpp';f.write_text(code);binary=Path(d)/'geometry'
 subprocess.run(['g++','-std=c++11',str(f),'-o',str(binary)],check=True)
 subprocess.run([str(binary)],check=True)
# Direct identity avoids waiting for yr-titlettl and is checked again on replacement.
assert 'ADPersonReturnsIdentity7521(n)||objc_getAssociatedObject' in p
assert 'ADPersonReturnsIdentity7521(p)' in b and 'ADInPersonTab7206(v)' in b
assert 'ADPersonReturnsOccluder7521(v)?[UIColor clearColor]:ADOLED()' in p
assert 'ADPersonBuyAgainOccluder7235(v)||ADPersonReturnsOccluder7521(v)' in t
for hook in ['didMoveToWindow','didMoveToSuperview','layoutSubviews']:
 block=t[t.index('%hook RCTView'):t.index('%end',t.index('%hook RCTView'))]
 assert '- (void)'+hook in block and 'ADOwnReactView7226' in block
# No replacement geometry/outline; React retains all original widths and corner radii.
for token in ['setBorderWidth:', 'setBorderRadius:', '.frame=', '.bounds=', '.cornerRadius=', '.mask=', '[CAShapeLayer layer]']:
 actual='\n'.join(x for x in p.splitlines() if not x.strip().startswith('//'))
 assert token not in actual,token
# Preserve data fields, batch limits and hydration. Change only cooperative idle wait.
walker=u[u.index('static void ADUINativeSnapshotAsync7449'):u.index('static NSString *gADUIProbeActivePath7433')]
assert 'batch<32' in walker and '<0.0035' in walker and '0.004*NSEC_PER_SEC' in walker
assert 'NATIVE_TIMING phase=' in walker
assert 'ADUIEdges7362(v)' in walker and 'ADUILayerMeta7362(v)' in walker
assert 'hydrationMs=340' in u and '0.34*NSEC_PER_SEC' in u
assert '(.30*NSEC_PER_SEC)' in u
print('PASS: captured Returns inset plane clears through hydration without geometry writes; full probe retains coverage and yielding')

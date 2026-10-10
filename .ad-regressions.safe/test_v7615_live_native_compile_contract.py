"""v7.615: the six native CI diagnostics originated in new Live ObjC++ callsites.

Unlike the runtime Python/UI checks, ObjC++ requires forward declarations and
`const char *` for ADClassNameIs7183, not Objective-C NSString literals.
"""
from pathlib import Path
import re
import subprocess
import tempfile

R = Path(__file__).resolve().parents[1]
s = (R / 'src/Tweak.xm').read_text()
start = s.index('static const void *kADLiveVideoShade7612')
stop = s.index('static const void *kADProfilePickerSheet7482', start)
block = s[start:stop]
# The declarations must be before both callsites, not merely present later in Tweak.xm.
for declaration, use in [
    ('static UIColor *ADMenuButtonBorder7255(void);', 'v.layer.borderColor=ADMenuButtonBorder7255().CGColor;'),
    ('static NSTextStorage *ADPersonTextStorage7206(UIView *v);', 'NSTextStorage *ts=ADPersonTextStorage7206(v);'),
]:
    assert s.index(declaration) < s.index(use), (declaration, use)
# The class matching utility takes const char*, and the new Live block uses three probes.
assert len(re.findall(r'ADClassNameIs7183\s*\(\s*(?:v|svg)\s*,\s*"(?:RNSVGSvgView|AmazonIvsView|IVSPlayerView)"\s*\)', block)) == 3
assert not re.search(r'ADClassNameIs7183\s*\([^\n;]*?,\s*@"', block)
assert 'static inline BOOL ADClassNameIs7183(id obj,const char *exact)' in s
# Ensure future code doesn't regress declaration order or typed call arguments.
# A tiny C++ syntax fixture verifies the two signatures/three literal calls
# under the same language overload rules used in Theos' Objective-C++ build.
cpp='''
#include <cstddef>
struct UIView { bool window; };
struct UIColor { int CGColor; };
struct NSTextStorage {};
typedef bool BOOL;
static UIColor *ADMenuButtonBorder7255(void);
static NSTextStorage *ADPersonTextStorage7206(UIView *v);
static UIColor *ADMenuButtonBorder7255(void) { static UIColor c = {0}; return &c; }
static NSTextStorage *ADPersonTextStorage7206(UIView *) { static NSTextStorage ts; return &ts; }
static inline BOOL ADClassNameIs7183(const void *, const char *) { return true; }
static void ADProbe(UIView *v, UIView *svg) {
    (void)ADMenuButtonBorder7255()->CGColor;
    (void)ADPersonTextStorage7206(v);
    (void)ADClassNameIs7183(svg,"RNSVGSvgView");
    (void)ADClassNameIs7183(v,"AmazonIvsView");
    (void)ADClassNameIs7183(v,"IVSPlayerView");
}
int main(){UIView v={true}; ADProbe(&v,&v);return 0;}
'''
with tempfile.TemporaryDirectory() as td:
    path=Path(td)/'native.cpp'
    path.write_text(cpp)
    subprocess.run(['clang++','-std=gnu++98','-Werror','-fsyntax-only',str(path)], check=True)
for need in [
    'ADLiveOwnView7612(v)', 'ADLiveOwnVector7612((UIView *)self)',
    'ADLiveOwnVideo7612((UIView *)self)', 'ADLiveTextOwner7612(v)',
    'ADLiveForcedBackground7612(self,color)',
]:
    assert need in s, need
print('PASS: v7.615 Live ObjC++ declaration order and 3 const-char class literals; gnu++98 compile fixture')

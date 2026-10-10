"""Regression for actual errors and format warning in archived 2026-10-10 Theos compiler log."""
from pathlib import Path
import re, subprocess, tempfile

R=Path(__file__).resolve().parents[1]
s=(R/'src/Tweak.xm').read_text()
control=(R/'layout/DEBIAN/control').read_text()
assert 'Version: 7.618~native-compiler-error-repair' in control
assert '#define AD_VERSION "v7.618-native-compiler-error-repair"' in s

# Exact error at v7.617 src/Tweak.xm:4309: ADMenuButtonFill7255 used before declaration.
forward='static UIColor *ADMenuButtonFill7255(void);'
call='if((selected||switcher)&&ADNeutralNearWhite7255(source))return ADMenuButtonFill7255();'
definition='static UIColor *ADMenuButtonFill7255(void){'
assert s.count(forward)==1
assert s.index(forward)<s.index(call)<s.index(definition)

# Exact error at v7.617 src/Tweak.xm:10348: liveText undeclared in RCTTextView 3-argument setter.
start=s.index('%hook RCTTextView\n')
end=s.index('- (void)setTextStorage:(NSTextStorage *)textStorage {',start)
hook=s[start:end]
declaration='BOOL liveText=gP.enabled&&ADLiveTextOwner7612(v);'
paint='if(liveText)ADMenuLightStorage7255(textStorage);'
post='if(liveText)ADLiveOwnText7612(v);'
assert hook.count(declaration)==1
assert hook.index(declaration)<hook.index(paint)<hook.index('%orig(textStorage,contentFrame,descendantViews);')<hook.index(post)

# Exact clang warning v7.617 src/Tweak.xm:2675: 5 conversions but 4 arguments.
fmt_line=next(x for x in s.splitlines() if 'ADReturnsThemeJS7480()' in x and 'stringWithFormat' in x)
assert 'gP.whiteTame,f,gP.whiteTame,f,f] stringByAppendingString:ADReturnsThemeJS7480()' in fmt_line
fmt=fmt_line.split('stringWithFormat:@"',1)[1].rsplit('"',1)[0]
assert re.findall(r'%(?:\d+)?(?:\.\d+)?[dsf@]',fmt)==['%d','%.3f','%d','%.3f','%.3f']

# Compile a minimal translation unit with the EXACT forward declaration, earlier
# call, and setter-local liveText line. A lexical regression cannot masquerade as
# a full iOS SDK compilation; the next gate remains the full macOS Theos build.
with tempfile.TemporaryDirectory() as td:
    p=Path(td)/'native_order.mm'
    p.write_text('''
@class UIColor;
@class UIView;
typedef signed char BOOL;
static BOOL ADNeutralNearWhite7255(UIColor *);
static BOOL ADLiveTextOwner7612(UIView *);
static void ADMenuLightStorage7255(void *);
static void ADLiveOwnText7612(UIView *);
struct prefs { BOOL enabled; }; static prefs gP;
''' +forward+'\n' + '''
static UIColor *theme(UIColor *source,BOOL selected,BOOL switcher){
'''+call+'''\n return source;
}
static void themeText(UIView *v,void *textStorage){
'''+declaration+'\n'+paint+'\n'+post+'''
}
''')
    subprocess.run(['clang++','-std=gnu++98','-x','objective-c++','-fsyntax-only',str(p)],check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
print('PASS v7.618: exact two Theos compiler errors and format argument mismatch fixed; isolated ObjC++ syntax check')

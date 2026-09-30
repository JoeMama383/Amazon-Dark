from pathlib import Path
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text()
I=(R/'src/ADBookTransitionSignOut7487.inc').read_text()
C=(R/'layout/DEBIAN/control').read_text()
CMD=(R/'COMMANDS.md').read_text()

assert 'Version: 7.487~book-transition-signout-v6185' in C
assert '#define AD_VERSION "v7.487-book-transition-signout-v6185"' in T
assert '#include "ADBookTransitionSignOut7487.inc"' in T

# Probe-backed early AMI root owner: exact class/responder + bright-neutral + near-full content geometry.
for tok in (
    'strcmp(cn,"UIView")!=0',
    'NSStringFromClass(r.class) isEqualToString:@"AMIWebViewController"',
    'ADBrightNeutral7130(c)',
    'vw<sw*0.94',
    'vh<sh*0.65',
    'kADBookAMIWebRoot7487',
): assert tok in I, tok
# It must win both mount and later Amazon background reassignment paths.
assert T.count('if(ADBookAMIWebRoot7487(self,self.backgroundColor))') == 1
assert T.count('if(ADBookAMIWebRoot7487(self,color))') == 1
assert 'ADSetViewBackground7226(self,ADOLED(),YES); return;' in T

# Exact v6.0.185 sign-out dialog ownership and donor palette.
for tok in (
    'strcmp(cn,"AWButton")==0',
    '[own isEqualToString:@"Sign Out"]',
    '[own isEqualToString:@"Cancel"]',
    '[t hasPrefix:@"You are signed in as "]',
    'colorWithWhite:0.40 alpha:1.0',
    'colorWithRed:0.831 green:0.627 blue:0.090 alpha:1.0',
    'resizableImageWithCapInsets:cap resizingMode:src.resizingMode',
    'UIControlStateNormal,UIControlStateHighlighted,UIControlStateSelected,UIControlStateDisabled',
): assert tok in I, tok
# Existing UIButton lifecycle is the only reassertion mechanism; no polling/scans are added.
assert 'ADPaintSignOutDialogButton7487(self);' in T
for bad in ('MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'", 'dispatch_after('):
    assert bad not in I, bad

for h in ('## FULL — v7.487','## VIEWPORT — v7.487','## TRANSITION — v7.487'):
    assert h in CMD, h
assert ' status' not in CMD.lower()
print('PASS: v7.487 owns the probe-proven AMI book transition root and ports the exact v6.0.185 Sign Out/Cancel visual contract')

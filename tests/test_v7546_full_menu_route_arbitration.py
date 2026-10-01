from pathlib import Path
R=Path(__file__).resolve().parents[1]
U=(R/'src/ADUniversalUIProbe7362.inc').read_text()
T=(R/'src/Tweak.xm').read_text()
C=(R/'layout/DEBIAN/control').read_text()
CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.546~full-menu-route-arbitration-repair' in C
assert '#define AD_VERSION "v7.546-full-menu-route-arbitration-repair"' in T
for token in ('ADUIOwnsHit7520','scrolled-hamburger-view','FULL_ROUTE_ARBITRATION','p=m'):
    assert token in U, token
capture=U[U.index('static void ADCaptureUniversalUIProbe7362(BOOL viewportOnly,NSString *trigger){'):U.index('static NSString *ADUIViewportArmPath7362')]
assert capture.index('UIView *menuWrap=ADUIMenuWrapper7520();') < capture.index('UIView *personWrap=ADUIPersonWrapper7519();')
assert capture.index('UIView *menuWrap=ADUIMenuWrapper7520();') < capture.index('ADUIDetectPDPSession7451(webs,^')
assert 'if(menuWrap){' in capture
assert 'ADUIScanMenuFull7520(path,cap' in capture
menu=U[U.index('static void ADUIScanMenuFull7520'):U.index('static void ADUIFinishCapture7364')]
assert 'setFrame:' not in menu and 'setBounds:' not in menu
assert 'r.scrollEnabled=' not in menu and 'root.scrollEnabled=' not in menu
assert '[r setContentOffset:orig animated:NO]' in menu
for good in ('ui-probe.sh export full','ui-probe.sh arm','ui-probe.sh export viewport','skeleton-probe.sh arm transition','skeleton-probe.sh export','git push origin main'):
    assert good in CMD, good
print('PASS: v7.546 makes foreground Hamburger ownership win over retained Person surfaces and recognizes both menu root identities')

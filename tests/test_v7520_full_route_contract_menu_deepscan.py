from pathlib import Path
R=Path(__file__).resolve().parents[1]
U=(R/'src/ADUniversalUIProbe7362.inc').read_text()
T=(R/'src/Tweak.xm').read_text()
C=(R/'layout/DEBIAN/control').read_text()

assert 'Version: 7.520~full-probe-route-contract-menu-deepscan' in C
assert '#define AD_VERSION "v7.520-full-probe-route-contract-menu-deepscan"' in T

capture=U[U.index('static void ADCaptureUniversalUIProbe7362(BOOL viewportOnly,NSString *trigger){'):U.index('static NSString *ADUIViewportArmPath7362')]
# Historical v7.450+ parser/test contract: never put another token between POLICY and pdpDetected.
assert 'FULL_ROUTE_POLICY pdpDetected=' in capture
assert 'FULL_ROUTE_POLICY personExact=' not in capture

# Person remains exact and wins over retained PDP surfaces when it is visibly active.
assert 'UIView *personWrap=ADUIPersonWrapper7519();' in capture
assert 'ADUIScanPersonFull7519(path,cap' in capture

# Hamburger is not generic candidate scoring: use its probe-proven React owner.
assert 'static UIView *ADUIMenuWrapper7520' in U
assert '[cn isEqualToString:@"RCTScrollView"]&&[aid isEqualToString:@"scrolled-hamburger"]' in U
assert 'static UIScrollView *ADUIMenuScroll7520' in U
assert '[cn isEqualToString:@"RCTCustomScrollView"]' in U
assert 'static void ADUIScanMenuFull7520' in U
assert 'MENU_FULL_MOVE step=' in U and 'MENU_FULL_SCAN_END' in U
assert 'ADUIScanMenuFull7520(path,cap' in capture
assert capture.index('UIView *menuWrap=ADUIMenuWrapper7520();') < capture.index('ADUIDetectPDPSession7451(webs,^')

# Dedicated native routes must preserve Amazon's interaction state and geometry.
menu=U[U.index('static void ADUIScanMenuFull7520'):U.index('static void ADUIFinishCapture7364')]
assert 'root.scrollEnabled=' not in menu
assert 'setFrame:' not in menu and 'setBounds:' not in menu
assert '[r setContentOffset:orig animated:NO]' in menu

print('PASS: v7.520 restores legacy FULL route contract and exact Hamburger RCTCustomScrollView deep scan')

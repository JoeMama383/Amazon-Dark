"""Alexa migrated to a main-window AppCX bottom sheet in the Oct 9 probe.
Restore old native styling without global reclassification or perpetual scans.
"""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
P=(ROOT/'src/ADUniversalUIProbe7362.inc').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.599~alexa-owner-full-recovery' in C
assert '#define AD_VERSION "v7.599-alexa-owner-full-recovery"' in S
for token in (
    'static BOOL ADAlexaModernOwner7599(UIView *v)',
    '[a isEqualToString:@"navigation-root"]',
    '[a isEqualToString:@"AppCXBottomSheetContentView"]',
    'static BOOL ADAlexaModernCard7599(UIView *v)',
    '[a hasPrefix:@"in-view-wrapper-ftuxRuxSuggestionCardList-"]',
    'ADMenuSetSingleRCTBorder7258(v,1.0,ADBorderGray706());',
    'static BOOL ADAlexaModernFloor7599(UIView *v)',
    '[a isEqualToString:@"MainNavigationHeader-header-bar"]',
    '[a isEqualToString:@"ShadowContainer"]',
    'ADAlexaModernOwner7599(v)){ ADAppCXSheetLightStorage7255(textStorage);',
    'ADAlexaSuggestionPillLightStorage7288(textStorage);',
    'ADAlexaModernOwner7599(svg)',
    'ADAlexaOwnPlusCircle7291(v)',
    'ADAlexaOwnVoiceCircle7295(v)',
): assert token in S,token
# The user-level source must not change the contract for menu and person.
for token in ('static UIView *ADUIAlexaRoot7599(void)',
              'static void ADUIScanAlexaFull7599(',
              'FULL_ROUTE_POLICY owner=Alexa navigation-root=',
              'ADUIScanMenuFull7520(path,cap',
              'ADUIScanPersonFull7519(path,cap',
              'ADUIFinishCapture7364(NO,webs,path,cap)'):
    assert token in P,token
for bad in ('MutationObserver','setInterval(','requestAnimationFrame('):
    assert bad not in P[P.index('static UIView *ADUIAlexaRoot7599'):P.index('static UIView *ADUIMenuWrapper7520')]
print('PASS: v7.599 migrated Alexa native ownership, exact card/pill/header/input and screenshot FULL route')

from pathlib import Path
import hashlib,re
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.510~orders-webkit-oled-keyboard' in C
assert '#define AD_VERSION "v7.510-orders-webkit-oled-keyboard"' in S
assert 'AmazonDark-v7.510-orders-webkit-oled-keyboard-source.zip' in CMD
assert len(S.encode()) < 856000, len(S.encode())
wk=S.split('%hook WKContentView',1)[1].split('%end',1)[0]
assert '- (UIKeyboardAppearance)keyboardAppearance' in wk
assert 'if(gP.enabled)return UIKeyboardAppearanceDark;' in wk
assert '- (BOOL)becomeFirstResponder' in wk
assert wk.count('ADPrepareSearchKeyboard7120')>=2
# Keep the proven OLED keyboard owners; do not replace them with hierarchy scans or compositor filters.
for tok in ('%hook UIKeyboard','%hook UIKeyboardDockView','%hook UIKBVisualEffectView','%hook UIInputSetHostView','%hook _UIRemoteKeyboardPlaceholderView','ADSetKeyboardFloor7126','ADOLED()'):
    assert tok in S,tok
# Core WebUI contract is untouched.
def func(name):
 st=S.index(f'static NSString *{name}'); b=S.index('{',st); d=0
 for i in range(b,len(S)):
  if S[i]=='{': d+=1
  elif S[i]=='}':
   d-=1
   if d==0:return S[st:i+1]
 raise AssertionError(name)
core=func('ADCoreWebJS7271').replace('] stringByAppendingString:ADNewMenusJS7482()',']').replace('=[[NSString','= [NSString').replace('()]];','()];').replace('= [NSString','=[NSString').replace('@"%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@"','@"%@%@%@%@"').replace(',ADProductShareThemeJS7403(),\n        ADProductShareTWBJS7403(),ADShareProbeSuppressJS7403(),ADProductScrollPolishJS7404(),\n        ADProductScrollVideoBorderJS7405(),ADPDPGridCarouselFix7454(),ADPDPCompletionJS7405(),ADPDPSafeFrameJS7432(),ADPDPCompletionTWBJS7405(),ADPDPUICompletionJS7439(),ADPDPMainResidualJS7440(),ADPDPProbeBackedFixesJS7458(),ADFrameOwnerTriggerJS7440(),ADAddressManagementJS7412()','')
assert hashlib.sha256(core.encode()).hexdigest()=='41ce925c9bad5362bf65204d4eb9778d016c2015b41b427704943df363b6d30c'
print('PASS: v7.510 ports the existing OLED keyboard contract to WebKit Orders search without changing core WebUI or probe behavior')

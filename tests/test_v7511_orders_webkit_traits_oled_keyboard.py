from pathlib import Path
import hashlib
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text(); V=(R/'scripts/validate.sh').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.511~orders-webkit-traits-oled-keyboard' in C
assert '#define AD_VERSION "v7.511-orders-webkit-traits-oled-keyboard"' in S
assert 'AmazonDark-v7.511-orders-webkit-traits-oled-keyboard-source.zip' in CMD
assert 'tests/test_v7510_orders_webkit_oled_keyboard.py' in V
assert not (R/'tests/test_v7510_orders_webkit_oled_keyboard.py').exists()
assert len(S.encode()) < 856000, len(S.encode())
# WebKit's actual remote-keyboard contract is the traits object, not WKContentView.keyboardAppearance.
wk=S.split('%hook WKContentView',1)[1].split('%end',1)[0]
assert 'static id ADDarkWebInputTraits7511' in S
assert '- (id)textInputTraits { return ADDarkWebInputTraits7511(%orig); }' in wk
assert '- (id)textInputTraitsForWebView { return ADDarkWebInputTraits7511(%orig); }' in wk
assert '- (UIKeyboardAppearance)keyboardAppearance' not in wk
helper=S.split('static id ADDarkWebInputTraits7511',1)[1].split('%hook WKContentView',1)[0]
assert '@selector(setKeyboardAppearance:)' in helper
assert 'UIKeyboardAppearanceDark' in helper
# Existing OLED floor/accessory owners remain in place and there is no hierarchy scanner.
for tok in ('%hook UIKeyboard','%hook UIKeyboardDockView','%hook UIKBVisualEffectView','%hook UIInputSetHostView','%hook _UIRemoteKeyboardPlaceholderView','ADSetKeyboardFloor7126','ADOwnWebFormAccessory7394'):
    assert tok in S,tok
for bad in ('MutationObserver(', 'setInterval(', 'requestAnimationFrame('):
    assert bad not in helper,bad
# Shared WebUI core hash remains untouched.
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
print('PASS: v7.511 drives the WebKit remote keyboard from its actual UITextInputTraits owner while preserving OLED floor/accessory owners')

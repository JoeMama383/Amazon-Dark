from pathlib import Path
import hashlib,re,subprocess,tempfile

ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
CTRL=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.398~legal-help-completion' in CTRL
assert '#define AD_VERSION "v7.398-legal-help-completion"' in S

def func(name):
    st=S.index(f'static NSString *{name}')
    b=S.index('{',st); d=0
    for i in range(b,len(S)):
        if S[i]=='{': d+=1
        elif S[i]=='}':
            d-=1
            if d==0: return S[st:i+1]
    raise AssertionError(name)

# v7.388 hashes reflect exact shorthand compaction and removal of an unused probe bridge.
# Semantic v7.386 CSS/palette parity is also checked by test_v7387_optimization.py.
assert hashlib.sha256(func('ADFloorJS').encode()).hexdigest() == '86730a2287803039c3912c5b0cd5f2bdca27464c63820a1c24a4aa3e24685d83'
assert hashlib.sha256(func('ADTWBJS').encode()).hexdigest() == 'a86f3c1257f32380057eb6c8c99c1c75e2c98f1fc5529364f4304feaa33821a3'
assert hashlib.sha256(func('ADCoreWebJS7271').encode()).hexdigest() == '41ce925c9bad5362bf65204d4eb9778d016c2015b41b427704943df363b6d30c'

floor=func('ADCheckoutFloorJS7369')
twb=func('ADCheckoutTWBJS7369')

# Root-cause repair: Amazon clears the real WKUserScripts. Every installation receipt must be
# cleared before the common attach function runs, including BOTH isolated checkout scripts.
hook=S[S.index('%hook WKUserContentController'):S.index('%end',S.index('%hook WKUserContentController'))]
remove=hook[hook.index('- (void)removeAllUserScripts'):hook.index('- (void)removeAllContentRuleLists')]
attach_at=remove.index('ADAttachScriptsToUCC710(self);')
for key in ['kADCoreWebUS7271','kADTWBUS','kADCheckoutFloorUS7369','kADCheckoutTWBUS7369','kADPrivacyUS7117']:
    token=f'objc_setAssociatedObject(self,{key},nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);'
    assert token in remove and remove.index(token)<attach_at,key

# Probe-backed before-you-go ownership and exact shared control palette.
for token in [
    '#checkoutDisplayPage.checkout-display-page', '.checkout-byg-mobile-container',
    '.checkout-byg-continue-button-shadow-mobile', '#checkout-byg-ptc-button.a-button-primary',
    '[class*=_denseGridAxSpotAtcButton_]', "button[name='submit.addToCart']",
    '[class*=_mobileDenseGridProductTitle_]', '[class*=_badgeMessage_]', 'i.a-icon-prime'
]: assert token in floor,token
assert '#303335!important' in floor and '#747a7c!important' in floor
assert 'filter:brightness(0) invert(1)!important' in floor
# Product title is the exact probe family nested under a-link-normal; it has an explicit light rule.
assert '[class*=_mobileDenseGridProductTitle_] *{color:#e8e6e3!important' in floor
# Semantic families keep authored color instead of being hard-coded white/red/green/blue.
assert '-webkit-text-fill-color:currentColor!important' in floor

# Place Your Order: surfaces/buttons/Cart stepper + preserved Prime/leaf.
for token in [
    '#checkout-experience-container','.rcx-checkout-custom-card','.checkout-card-color','.lineitem-container',
    '#placeYourOrder','#placeYourOrderSecondary',"fieldset[name='checkout-quantity-stepper']",
    '.a-stepper-inner-container','.a-icon-small-trash,.a-icon-small-add',
    'img.sustainability-green-leaf-alignment-updated'
]: assert token in floor,token
assert "fieldset[name='checkout-quantity-stepper']{background:transparent!important" in floor
assert '.a-stepper-inner-container{background:#303335!important' in floor
# Probe-proven black a-color-base anchors (sustainability + expander) must be light, not forced blue.
assert '#checkoutDisplayPage a.a-color-base,#checkoutDisplayPage a.a-color-base *{color:#e8e6e3!important' in floor
assert 'rgb(33,98,161)!important' not in floor
assert 'rgb(11,123,60)!important' not in floor

# Checkout-only media taming remains isolated; glyph/artwork lanes are excluded.
assert '#checkoutDisplayPage .checkout-byg-mobile-container img[class*=_mobileDenseGridImage_]' in twb
assert '#checkoutDisplayPage img.checkout-product-image' in twb
assert 'i.a-icon-prime' in twb and 'sustainability-green-leaf-alignment-updated' in twb
for forbidden in ['#gwm-Deck','hp-mosaic','single-creative-card','video.vjs-tech']:
    assert forbidden not in twb

# Native header: exact checkout scope, all-label title search, and light title/DONE/back ownership.
for token in ['AMSModalLayoutFullScreenViewController','ADCheckoutTitleMatches7369','Place Your Order',
              'ADOwnCheckoutNav7369','kADCheckoutNavLabelOldColor7370']:
    assert token in S,token
title=S[S.index('static BOOL ADCheckoutTitleMatches7369'):S.index('static BOOL ADCheckoutControllerChain7369')]
assert 'return YES' in title and 'while(stack.count&&visited++<64)' in title
nav=S[S.index('static void ADOwnCheckoutNav7369'):S.index('%hook _UIBarBackground')]
assert 'label.textColor=ADLightText706();' in nav
assert 'ADMarkCheckoutNav7375(nav);' in nav
assert 'nav.tintColor=[UIColor whiteColor];' in nav

# Checkout floor program itself must be valid JavaScript after concatenating Objective-C literals.
# This specifically guards against the v7.368 quote/string regression.
lits=re.findall(r'@"((?:\\.|[^"\\])*)"', floor)
assert lits
js=''.join(bytes(x,'utf-8').decode('unicode_escape') for x in lits)
with tempfile.NamedTemporaryFile('w',suffix='.js',delete=False) as f:
    f.write(js); js_path=f.name
r=subprocess.run(['node','--check',js_path],text=True,capture_output=True)
Path(js_path).unlink(missing_ok=True)
assert r.returncode==0,r.stderr

# No live/recurring production scanner added.
for bad in ['MutationObserver(', 'setInterval(', 'requestAnimationFrame(']:
    assert bad not in floor and bad not in twb

print('PASS: v7.370 re-installs isolated checkout scripts after Amazon clears them, fixes probe-proven text/color misses, and hardens the exact native checkout header')

from pathlib import Path
import hashlib,re
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
CTRL=(ROOT/'layout/DEBIAN/control').read_text()

assert 'Version: 7.391~ui-completion-audit-fix' in CTRL
assert '#define AD_VERSION "v7.391-ui-completion-audit-fix"' in S

def func(name):
    st=S.index(f'static NSString *{name}')
    b=S.index('{',st); d=0
    for i in range(b,len(S)):
        if S[i]=='{': d+=1
        elif S[i]=='}':
            d-=1
            if d==0: return S[st:i+1]
    raise AssertionError(name)

# Critical shared theming programs remain stable; v7.388 changes only the core concatenation to append the tiny Home ad-shell floor.
assert hashlib.sha256(func('ADFloorJS').encode()).hexdigest() == '86730a2287803039c3912c5b0cd5f2bdca27464c63820a1c24a4aa3e24685d83'
assert hashlib.sha256(func('ADTWBJS').encode()).hexdigest() == 'a86f3c1257f32380057eb6c8c99c1c75e2c98f1fc5529364f4304feaa33821a3'
assert hashlib.sha256(func('ADCoreWebJS7271').encode()).hexdigest() == '41ce925c9bad5362bf65204d4eb9778d016c2015b41b427704943df363b6d30c'

for x in ['ADCheckoutFloorJS7369','ADCheckoutTWBJS7369','kADCheckoutFloorUS7369','kADCheckoutTWBUS7369',
          'ADSharedUserScript7387(4,ADCheckoutFloorJS7369,NO,NO)','ADSharedUserScript7387(5,ADCheckoutTWBJS7369,NO,YES)']:
    assert x in S,x

floor=func('ADCheckoutFloorJS7369')
twb=func('ADCheckoutTWBJS7369')

# Probe-backed BYG owners, exact footer and plus button.
for x in ['#checkoutDisplayPage.checkout-display-page','.checkout-byg-mobile-container',
          '.checkout-byg-continue-button-shadow-mobile','#checkout-byg-ptc-button.a-button-primary',
          '[class*=_denseGridAxSpotAtcButton_]',"button[name='submit.addToCart']",
          '[class*=_badgeMessage_]']:
    assert x in floor,x
assert "#303335!important" in floor and "#747a7c!important" in floor
assert "filter:brightness(0) invert(1)!important" in floor

# Probe-backed checkout owners and exact Cart stepper geometry/palette.
for x in ['#checkout-experience-container','.rcx-checkout-custom-card','.checkout-card-color',
          '.lineitem-container','#placeYourOrder','#placeYourOrderSecondary',
          "fieldset[name='checkout-quantity-stepper']",'.a-icon-small-trash,.a-icon-small-add',
          'img.sustainability-green-leaf-alignment-updated','.a-color-success']:
    assert x in floor,x
assert "fieldset[name='checkout-quantity-stepper']{background:transparent!important" in floor
assert ".a-stepper-inner-container{background:#303335!important" in floor
assert '-webkit-text-fill-color:currentColor!important' in floor
assert ':not(.a-color-price)' in floor and ':not([class*=_badgeMessage_])' in floor

# TWB affects only checkout product media; Prime and sustainability artwork are preserved.
assert '#checkoutDisplayPage .checkout-byg-mobile-container img[class*=_mobileDenseGridImage_]' in twb
assert '#checkoutDisplayPage img.checkout-product-image' in twb
assert 'i.a-icon-prime' in twb and 'sustainability-green-leaf-alignment-updated' in twb
for forbidden in ['#gwm-Deck','hp-mosaic','single-creative-card','video.vjs-tech']:
    assert forbidden not in twb

# Native banner is exact checkout modal + Place Your Order title, not all bars.
for x in ['ADCheckoutControllerChain7369','AMSModalLayoutFullScreenViewController',
          'ADCheckoutTitleMatches7369','Place Your Order','ADOwnCheckoutNav7369',
          'kADCheckoutNavImageHidden7369']:
    assert x in S,x
hook=S[S.index('%hook _UIBarBackground'):S.index('%end',S.index('%hook _UIBarBackground'))]
assert 'ADOwnCheckoutNav7369(self);' in hook
assert '- (void)layoutSubviews' not in hook
assert '- (void)didMoveToSuperview' in hook

# No recurring production scanner was introduced.
for bad in ['MutationObserver(', 'setInterval(', 'requestAnimationFrame(']:
    assert bad not in floor and bad not in twb

print('PASS: current build retains v7.369 isolated checkout architecture, authored colors/artwork, Cart controls, and stable shared WebUI')

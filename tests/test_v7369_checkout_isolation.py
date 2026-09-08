from pathlib import Path
import hashlib

ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
CTRL=(ROOT/'layout/DEBIAN/control').read_text()

assert 'Version: 7.369~checkout-isolated-theme' in CTRL
assert '#define AD_VERSION "v7.369-checkout-isolated-theme"' in S

# The stable shared web programs must remain byte-for-byte at the v7.367 hashes.
def func(name):
    st=S.index(f'static NSString *{name}')
    b=S.index('{',st); d=0
    for i in range(b,len(S)):
        if S[i]=='{': d+=1
        elif S[i]=='}':
            d-=1
            if d==0: return S[st:i+1]
    raise AssertionError(name)

assert hashlib.sha256(func('ADFloorJS').encode()).hexdigest() == '5fcc2badb75d385b84a9e67a1daab376c1dd277479c6c1071ead93e3ee96221d'
assert hashlib.sha256(func('ADTWBJS').encode()).hexdigest() == '74035e2572891f3b6014522bf4838d19a72a1dc1dfb894363eb8fec53cae5dd9'
assert hashlib.sha256(func('ADCoreWebJS7271').encode()).hexdigest() == 'e3d9e2edec398c434986eb423aa1d9a4a4fbde73db21d19be5727934a517f480'

# Checkout lives in independent document-start scripts so a checkout parse error cannot kill the shared floor/TWB programs.
for x in ['ADCheckoutFloorJS7369','ADCheckoutTWBJS7369','kADCheckoutFloorUS7369','kADCheckoutTWBUS7369']:
    assert x in S, x
assert 'initWithSource:ADCheckoutFloorJS7369()' in S
assert 'initWithSource:ADCheckoutTWBJS7369()' in S

# Probe-backed BYG owners, including the fixed footer that is outside the grid container.
for x in [
    '#checkoutDisplayPage.checkout-display-page',
    '.checkout-byg-mobile-container',
    '.checkout-byg-continue-button-shadow-mobile',
    '#checkout-byg-ptc-button.a-button-primary',
    '[class*=_denseGridAxSpotAtcButton_]',
    "button[name='submit.addToCart']",
    '[class*=_mobileDenseGridImage_]',
    '[class*=_badgeMessage_]',
]: assert x in S, x

# Probe-backed Place Order owners and exact Cart-style quantity stepper outer fieldset.
for x in [
    '#checkout-experience-container', '.rcx-checkout-custom-card', '.checkout-card-color',
    '.lineitem-container', '#placeYourOrder', '#placeYourOrderSecondary',
    "fieldset[name='checkout-quantity-stepper']", '.a-icon-small-trash,.a-icon-small-add',
    'img.sustainability-green-leaf-alignment-updated', '.a-link-legal', '.pipeline-link', '.a-color-success',
]: assert x in S, x
assert "fieldset[name='checkout-quantity-stepper']{background:#303335!important" in S
assert 'rgb(33,98,161)!important' in S
assert 'rgb(11,123,60)!important' in S
assert '#303335!important' in S and '#747a7c!important' in S and '#494d4d!important' in S

# Native banner ownership is limited to the probed checkout modal AND the actual Place Your Order title.
for x in ['ADCheckoutControllerChain7369','AMSModalLayoutFullScreenViewController','ADCheckoutTitleMatches7369','Place Your Order','ADOwnCheckoutNav7369']:
    assert x in S, x
assert 'AMIWebViewController' not in func('ADCheckoutFloorJS7369')

# Checkout TWB is narrow; the new selector never names Home/GWM/hero surfaces.
twb=func('ADCheckoutTWBJS7369')
assert '#checkoutDisplayPage .checkout-byg-mobile-container img[class*=_mobileDenseGridImage_]' in twb
assert '#checkoutDisplayPage img.checkout-product-image' in twb
for forbidden in ['#gwm-Deck','hp-mosaic','single-creative-card','video.vjs-tech']:
    assert forbidden not in twb, forbidden

# No new recurring scanner machinery.
for bad in ['MutationObserver(', 'setInterval(', 'requestAnimationFrame(']:
    assert bad not in func('ADCheckoutFloorJS7369')
    assert bad not in twb

print('PASS: v7.369 isolates checkout theming from v7.367 shared WebUI/TWB, owns fixed footer + quantity outer fieldset, and scopes native header to Place Your Order')

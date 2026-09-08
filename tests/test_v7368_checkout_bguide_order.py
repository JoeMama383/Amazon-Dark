from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
U=(ROOT/'src/ADUniversalUIProbe7362.inc').read_text()
JS=(ROOT/'src/ADUniversalUIProbe7362.js.inc').read_text()
CTRL=(ROOT/'layout/DEBIAN/control').read_text()

assert 'Version: 7.368~checkout-byg-order-theme' in CTRL
assert '#define AD_VERSION "v7.368-checkout-byg-order-theme"' in S

# Before-you-go renderer from r1.
for x in [
    '#checkoutDisplayPage.checkout-display-page',
    '.checkout-byg-mobile-container',
    '#checkout-byg-ptc-button.a-button-primary',
    '[class*=_denseGridAxSpotAtcButton_] button[name=\\"submit.addToCart\\"]',
    '[class*=_mobileDenseGridImage_]',
    '[class*=_badgeMessage_]',
]:
    assert x in S, x
assert '#303335!important' in S and '#747a7c!important' in S
# Preserve Prime and probed red deal badge family.
assert '#checkoutDisplayPage .checkout-byg-mobile-container i.a-icon-prime{filter:none!important' in S
assert ':not([class*=_badgeMessage_])' in S

# Place Order renderer from r2.
for x in [
    '#checkout-experience-container',
    '.rcx-checkout-custom-card',
    '.checkout-card-color',
    '.lineitem-container',
    '#placeOrder', '#placeYourOrder', '#placeYourOrderSecondary',
    'fieldset[name=\\"checkout-quantity-stepper\\"]',
    '.a-icon-small-trash,.a-icon-small-add',
    'img.sustainability-green-leaf-alignment-updated',
    '.a-link-legal', '.pipeline-link', '.a-color-success',
]:
    assert x in S, x
assert 'rgb(33,98,161)!important' in S  # probe-authored Amazon blue links
assert 'rgb(11,123,60)!important' in S  # probe-authored success green
assert '#checkoutDisplayPage i.a-icon-prime{filter:none!important' in S
assert 'img.sustainability-green-leaf-alignment-updated{filter:none!important' in S

# Product imagery enters the existing user-controlled TWB lane, not glyph lanes.
assert '#checkoutDisplayPage .checkout-byg-mobile-container img[class*=_mobileDenseGridImage_]' in S
assert '#checkoutDisplayPage img.checkout-product-image' in S

# Native checkout modal banner is probe-scoped to the actual Apple/Amazon controller family.
for x in ['ADInCheckoutModal7368','AMSModalLayoutFullScreenViewController','AMIWebViewController','ADOwnCheckoutNav7368','kADCheckoutNavImage7368']:
    assert x in S, x
assert '%hook _UIBarBackground' in S
assert '- (void)layoutSubviews {' in S[S.index('%hook _UIBarBackground'):S.index('%end',S.index('%hook _UIBarBackground'))]

# Universal probe identity advances, architecture stays two-mode/universal.
assert 'AMAZONDARK v7.368 UNIVERSAL' in U
assert 'AmazonDark-v7.368-ui-viewport.arm' in U
assert "version:'7.368'" in JS
assert 'route_policy=universal' in U

# No recurring/live production scanner added by this UI patch.
for bad in ['MutationObserver(', 'setInterval(', 'requestAnimationFrame(']:
    assert bad not in S, bad

print('PASS: v7.368 probe-backed BYG + Place Order owners, dynamic-color preservation, controls, TWB and native checkout banner are present')

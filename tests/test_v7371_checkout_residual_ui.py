from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.377~byg-stepper-hydration-switcher-source-fix' in C
assert '#define AD_VERSION "v7.377-byg-stepper-hydration-switcher-source-fix"' in S

# r1: ATC overlay plumbing must stay transparent so it cannot cut across product photos.
for tok in [
    '.byg-dense-grid-atc-container :is(.atc-faceout-container,.ax-replace)',
    '[class*=_denseGridAxSpotAtcOverlay_] :is(.atc-faceout-container,.ax-replace)',
    '{background:transparent!important;background-color:transparent!important;background-image:none!important;box-shadow:none!important;}',
]:
    assert tok in S, tok

# r3: exact payment text, manufacturer dropdown, and pressed checkbox owners.
for tok in [
    '#payment-option-text-default',
    '#payment-option-text-1',
    '#concealmentDropdown-0-dropdown',
    '#sns-item-sfco-t1-0 .a-checkbox.a-touch-checkbox.a-touch-press',
    '#sns-item-sfco-t1-0 .a-icon-checkbox',
]:
    assert tok in S, tok
assert '#checkoutDisplayPage #concealmentDropdown-0-dropdown' in S and '{background:#000!important' in S
assert '#checkoutDisplayPage #concealmentDropdown-0-dropdown>.a-button-inner' in S
assert 'border:1px solid #747a7c!important' in S
assert '#checkoutDisplayPage #sns-item-sfco-t1-0 .a-icon-checkbox' in S and '{filter:none!important' in S

# r3 native: direct image-backed bar leaf gets a lifecycle reassertion, and title ownership no
# longer depends on the failing responder-chain controller gate.
assert 'ADOwnCheckoutNavImage7371' in S
assert 'ADCheckoutNavImageMatches7371' in S
assert '- (void)setHidden:(BOOL)hidden {' in S
assert 'BOOL checkout=gP.enabled&&nav&&(modalOwned||ADCheckoutNavActive7375(nav));' in S
assert 'gP.enabled&&nav&&ADCheckoutControllerChain7369((UIView *)bar)&&ADCheckoutTitleMatches7369(nav)' not in S
for lifecycle in ['%orig(finalImage);\n    ADOwnCheckoutNavImage7371(self);',
                  '- (void)didMoveToWindow {\n    %orig;\n    ADOwnCheckoutNavImage7371(self);',
                  '- (void)layoutSubviews {\n    %orig;\n    ADOwnCheckoutNavImage7371(self);']:
    assert lifecycle in S, lifecycle


# DONE button: r3 exposed a dark _UIModernBarButton titleColor/tint even while its UILabel was light.
for tok in ['kADCheckoutNavButtonOldTint7371','kADCheckoutNavButtonOldTitle7371',
            '[button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]',
            '[button setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted]']:
    assert tok in S, tok

# Keep checkout isolated; no recurring production scanner.
st=S.index('static NSString *ADCheckoutFloorJS7369')
en=S.index('static NSString *ADPrivacyModeJS7117',st)
frag=S[st:en]
for bad in ['MutationObserver(', 'setInterval(', 'requestAnimationFrame(']:
    assert bad not in frag
print('PASS: v7.371 residual checkout/BYG probe-backed fixes present')

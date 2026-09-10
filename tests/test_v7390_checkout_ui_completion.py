from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.392~probe-handoff-ci-fix' in C
assert '#define AD_VERSION "v7.392-probe-handoff-ci-fix"' in S
floor=S[S.index('static NSString *ADCheckoutFloorJS7369'):S.index('static NSString *ADCheckoutTWBJS7369')]
twb=S[S.index('static NSString *ADCheckoutTWBJS7369'):S.index('// v7.378:',S.index('static NSString *ADCheckoutTWBJS7369'))]
# Help & Contact Us exact topic-card family; orange state stays authored.
for x in ['#csg-support-topics','.a-box.a-vertical','i.a-icon-touch-link','.a-color-state']:
    assert x in floor,x
# Subscribe loading: exact blocker and raster-owning spinner image.
for x in ['#loading-spinner-blocker-doc.loading-spinner-blocker','loading-spinner-inner-no-box','#loading-spinner-img.loading-spinner-img','rgba(0,0,0,.74)','invert(1) hue-rotate(180deg)']:
    assert x in floor,x
# Lower-carbon portal sheet.
for x in ['#ad-sm-program-modal','.a-sheet-web:has(#ad-sm-program-modal)']:
    assert x in floor,x
# Gift options: card floors, normalized fields, preserved checkbox, OLED Continue.
for x in ['#giftForm','#gift-options-box-0','.gift-message-textarea','.sender-name-input-group','.sender-name-text-input','.chewbacca-save-gift-options-buttons','.toggle-gift-checkbox']:
    assert x in floor,x
# Checkout Maple upsell + TWB uses the user's existing factor rather than a new hard-coded strength.
for x in ['#checkout-maple-upsell','.maple-banner__container','.maple-banner__text']:
    assert x in floor,x
assert '#checkoutDisplayPage #checkout-maple-upsell .maple-banner__image img' in twb
assert 'filter:brightness(%.3f)!important' in twb
# Select Payment Method: stable testids, black selected fill while preserving blue selection border and switch/art painters.
for x in ["form.pmts-select-payment-instrument-form","[data-testid='selectFrameContentTestId']","[data-testid='boxGroup']","[data-testid='selected-primary-pm-card']","[data-testid='unselected-primary-pm-card']","[data-testid='unselected-primary-pm-loan']","[data-testid='selected-balance-pm-giftcard']","[data-testid='claim-code']","[data-testid='sticky-footer']","[data-testid='art']","[data-testid='image']","[data-testid*='switch']","#cruise",".cruise-upx-box"]:
    assert x in floor,x
assert "[data-testid='selected-primary-pm-card']" in floor and "border-color:rgb(33,98,161)!important" not in floor
# Delivery-address cards/buttons and radio/link preservation.
for x in ['#shipping-address-select-page-card-deck','.destination-accordion-row','.a-button-primary','.a-button-base','.shipping-address-select-card-divider','.a-icon-radio-active']:
    assert x in floor,x
# Recurrence AUI popover; selected blue border retained.
for x in ["sns-recurrence-period-bottomsheet-dropdown-sfco-0_",'.a-popover-wrapper','a.a-dropdown-link.a-active']:
    assert x in floor,x
# Palette and architecture remain consistent with AmazonDark's established UI contract.
for x in ['#000!important','#303335!important','#747a7c!important','#e8e6e3!important']:
    assert x in floor,x
new=floor[floor.index('// v7.390 FULL r1:'):floor.index('// v7.373 FULL r1/r2:')]
for bad in ['MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'", 'setTimeout(']:
    assert bad not in new,bad
print('PASS: v7.390 probe-backed seven-surface checkout/support UI completion + Subscribe loader')

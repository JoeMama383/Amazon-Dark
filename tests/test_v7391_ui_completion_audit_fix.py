from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.416~location-canonical-owner' in C
assert '#define AD_VERSION "v7.416-location-canonical-owner"' in S
floor=S[S.index('static NSString *ADCheckoutFloorJS7369'):S.index('static NSString *ADCheckoutTWBJS7369')]
# Audit miss 1: visible Help H1 is outside #csg-support-topics.
assert '.cs-help-content>article.help-content>h1' in floor
# Audit miss 2: direct text on both Maple text containers must inherit light neutral ink.
assert '#checkoutDisplayPage #checkout-maple-upsell .maple-banner__text,' in floor
assert '#cruise .maple-banner__text,#cruise .maple-banner__text :is(span,strong,b)' in floor
# Authored blue links remain preserved.
assert '#checkoutDisplayPage #checkout-maple-upsell .maple-banner__text .a-color-link' in floor
assert '#cruise .maple-banner__text .a-color-link' in floor
# Audit miss 3: exact address divider gradient/white OR backing are neutralized.
assert '.shipping-address-select-card-divider .a-divider-inner:after' in floor
assert 'background-image:none!important;border-color:#747a7c!important' in floor
assert '.a-divider.a-divider-break:after{border-color:#747a7c!important;}' in floor
assert '.a-divider.a-divider-break>h5{background:#000!important' in floor
# All seven v7.390 surface owners and loader still exist.
for x in ['#csg-support-topics','#loading-spinner-blocker-doc.loading-spinner-blocker','#ad-sm-program-modal','#giftForm','#checkout-maple-upsell',"[data-testid='selectFrameContentTestId']",'#shipping-address-select-page-card-deck',"sns-recurrence-period-bottomsheet-dropdown-sfco-0_"]:
    assert x in floor,x
# Selected payment and recurrence blue borders must not be hard-recolored by the audit patch.
audit=floor[floor.index('// v7.390 FULL r1:'):floor.index('// v7.373 FULL r1/r2:')]
assert "[data-testid='selected-primary-pm-card']" in audit
assert 'border-color:rgb(33,98,161)!important' not in audit
for bad in ['MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'", 'setTimeout(']:
    assert bad not in audit,bad
print('PASS: v7.391 closes the three probe-confirmed v7.390 residual UI paint gaps')

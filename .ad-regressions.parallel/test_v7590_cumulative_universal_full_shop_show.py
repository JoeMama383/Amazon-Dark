"""Cumulative v7.619 contract: all post-v7.585 UI work plus renderer-neutral FULL and Shop the Show media."""
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
N=(ROOT/'src/ADNewMenus7482.js.inc').read_text()
P=(ROOT/'src/ADUniversalUIProbe7362.inc').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()

assert 'Version: 7.619~handoff-regression-repair' in C
assert '#define AD_VERSION "v7.619-handoff-regression-repair"' in S

# v7.586 medical / Health AI / auth follow-up stays cumulative.
for token in [
    '#warblerApplicationRoot [data-testid=wfe-send-message-btn]{background:#303335!important',
    'border:0!important;border-color:transparent!important',
    ':is(.k2eBglky,[class*=fade],[class*=gradient],[class*=mask])::before',
    'body:has(#verification-code-form) :is(#auth-footer,.auth-footer,footer,.a-footer',
]: assert token in N, token

# v7.587 exact medical/auth bottom-sheet owners remain.
for token in [
    'pui-bottom-sheet#links-bottomsheet',
    'pui-bottom-sheet#glowModal',
    'a#mobile-kyanite-logo{filter:none!important',
    'body:has(#verification-code-form) :is(#cvf-page-content>.a-row:first-child',
]: assert token in N, token

# v7.588 exact PDP coupon / package-info / image-viewer owners remain.
for token in [
    '#promoPriceBlockMessage_feature_div .ct-coupon-tile',
    '#promoPriceBlockMessage_feature_div .ct-coupon-tile-claimed',
    'path.ct-coupon-success-icon-background',
    '#dynamicPackageInfoFeature_feature_div .offer-display-feature-text-link',
    'static BOOL ADPDPThumbnailStripFloor7588',
    'static void ADPDPApplyThumbnailTWB7588',
]: assert token in S, token

# v7.589 compact Orders magnifier + exact Your Review page remain.
for token in [
    'static BOOL ADPersonOrderSearchCompactHost7589',
    'w<172.0||w>176.0||h<48.0||h>52.0',
]: assert token in S, token
for token in [
    'body:has(#cr-single-review) .a-subheader',
    'body:has(#cr-single-review) #cr-single-review [class*=_cr-single-review_style_contain-rich-content__]',
    '.a-button[class*=_cr-single-review_style_single-review-button__]{background:#000!important',
]: assert token in N, token

# Shop the Show is exact to the probe-proven AppCX/RN owner families.
for token in [
    'static BOOL ADShopShowScope7590',
    '@"home-page-banner"',
    '@"keep-shopping-the-shows"',
    '@"product-image-view-"',
    '@"keep-shopping-product-button-"',
    '@"mosaic-content-card_"',
    '@"campaign-card_"',
    '@"navigation-thumbnail-image-"',
    'iv.contentMode=UIViewContentModeScaleAspectFill',
    'ADEnsureNativeTWBOverlay7270(iv)',
]: assert token in S, token
assert 'ADShopShowProductFloor7590(v,color)' in S
assert 'ADShopShowApplyImage7590((UIImageView *)self)' in S

# v7.619 Shop the Show UI ownership remains cumulative. Its attempted FULL
# foreground arbitration was intentionally superseded by v7.591 after device
# testing proved it regressed Menu/Person and other native FULL walks. Do not
# resurrect those broken arbitration tokens as part of the UI contract.
for bad in [
    'static CGFloat ADUIForegroundOwnership7590',
    'NATIVE_SCROLL_REJECT',
    'policy=foreground-hit-tested renderer-neutral=1',
    'rendererPolicy=dynamic-web-native-react-equal',
]: assert bad not in P, bad
assert 'ADUIScanMenuFull7520' in P
assert 'ADUIScanPersonFull7519' in P
assert 'ADUINativeScrollCandidatesAsync7449' in P
assert 'ADUIProcessWebViews7364' in P

print('PASS: v7.619 cumulative post-v7.585 UI and exact Shop the Show media ownership retained; broken FULL arbitration remains retired')

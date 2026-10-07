"""Regression for v7.588 exact PDP coupon, thumbnail rail, and sustainability follow-up."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
src = (ROOT / 'src' / 'Tweak.xm').read_text()
control = (ROOT / 'layout' / 'DEBIAN' / 'control').read_text()

assert 'Version: 7.588~pdp-coupon-thumbnail-sustainability-followup' in control
assert '#define AD_VERSION "v7.588-pdp-coupon-thumbnail-sustainability-followup"' in src
assert '#promoPriceBlockMessage_feature_div .ct-coupon-tile' in src
assert '#promoPriceBlockMessage_feature_div .ct-coupon-tile-claimed' in src
assert 'background:#008000!important' in src
assert 'path.ct-coupon-success-icon-background{fill:#000!important' in src
assert '#dynamicPackageInfoFeature_feature_div .offer-display-feature-text-link' in src
assert 'color:#6cb6ff!important' in src
assert 'static BOOL ADPDPThumbnailStripFloor7588' in src
assert 'static BOOL ADPDPThumbnailImage7588' in src
assert 'static void ADPDPApplyThumbnailTWB7588' in src
assert '[aid isEqualToString:@"thumbnails-view"]' in src
print('PASS: v7.588 exact PDP coupon states, dynamic package info text, and native product-image thumbnail rail ownership present')

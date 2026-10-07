"""Regression for v7.589 Person Search-orders magnifier and Your Review menu."""
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
N=(ROOT/'src/ADNewMenus7482.js.inc').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()

assert 'Version: 7.589~person-orders-review-menu-followup' in C
assert '#define AD_VERSION "v7.589-person-orders-review-menu-followup"' in S
# Probe-captured compact Search Orders geometry: 174x50 host with direct image + text-input children.
assert 'static BOOL ADPersonOrderSearchCompactHost7589' in S
assert 'w<172.0||w>176.0||h<48.0||h>52.0' in S
assert 'ADClassNameIs7183(c,"RNCEKVTextInputFocusWrapper")' in S
assert 'ADClassNameIs7183(c,"RCTImageView")' in S
assert 'ADPersonOrderSearchCompactHost7589(host)' in S
# Legacy expanded owner remains intact.
assert 'ADPersonOrderSearchInner7242(host)' in S
# Exact Your Review web owner.
assert 'body:has(#cr-single-review) .a-subheader h4' in N
assert 'body:has(#cr-single-review) #cr-single-review :is([class*=_cr-single-review_style_card-deck__],[class*=_cr-single-review_style_peek-expand__])' in N
assert 'body:has(#cr-single-review) #cr-single-review [class*=_cr-single-review_style_contain-rich-content__]' in N
assert 'background:#000!important' in N
assert 'color:#fff!important' in N
assert 'border:1px solid #747a7c!important' in N
assert '.a-button[class*=_cr-single-review_style_single-review-button__]' in N
print('PASS: v7.589 exact compact Orders magnifier and Your Review OLED/text/button owners present')

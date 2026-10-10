"""Regression guard for v7.598 PDP reviews/ad follow-up work."""
from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
RB=''.join(json.loads(l) for l in (ROOT/'src/ADReviewBusiness7593.js.inc').read_text().splitlines())
MF=''.join(json.loads(l) for l in (ROOT/'src/ADMenuFollowup7595.js.inc').read_text().splitlines())
CMD=(ROOT/'COMMANDS.md').read_text()

assert 'Version: 7.619~handoff-regression-repair' in C
assert '#define AD_VERSION "v7.619-handoff-regression-repair"' in S
assert '## FULL — v7.619' in CMD and '## VIEWPORT — v7.619 ARM' in CMD and '## TRANSITION — v7.619 ARM' in CMD

# Review page follow-up: broader review image gallery restoration + top product header visibility.
for tok in (
    ':is(#mobile-product-reviews,#cruise-customer-reviews,#cm_cr-review_list) :is(.review-image-tile-section',
    'body:has(#mobile-product-reviews):not(:has(#dp)) #a-page :is(.cr-original-product-title',
    'body:has(#mobile-product-reviews):not(:has(#dp)) #a-page :is(.a-divider-inner,[class*=divider],[class*=Divider])',
):
    assert tok in RB, tok

# PDP follow-up: FBT images, standalone/sponsored image restoration, and OLED Add to cart buttons.
for tok in (
    '[class*="_p13n-mobile-sims-fbt_fbt-mobile_image-display__"]',
    ':is([id^=sp_phoneapp_detail],[id*=sp_phoneapp_detail],[data-testid=renderer-factory-ad-container]:has(#offsite-buy-box),#offsite-buy-box,.sponsored-products-detail-mobile)',
    ':is(.a-button,.a-button-primary,.a-button-base,button,[role=button]){background:#000!important',
    ':is([id$=_image_container_wrapper],[class*=image_container_wrapper],[data-testid=image],[data-testid=image-container],.a-image-container,.product-image-container)',
    'img:not([class*=icon]):not([class*=logo]):not([class*=star]):not([class*=prime]):not([class*=rating]){filter:brightness(__AD7595_FACTOR__)!important',
):
    assert tok in MF, tok

print('PASS: v7.598 restores review-page media/header and PDP sponsored/FBT follow-up owners')

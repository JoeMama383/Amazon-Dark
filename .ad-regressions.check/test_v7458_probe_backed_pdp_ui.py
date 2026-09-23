from pathlib import Path
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text()
assert 'ADPDPProbeBackedFixesJS7458' in T
for token in [
    '.mshop-subnav-bar', '#mshop-subnav-scrollable', '.mshop-subnav-link',
    '#rich_product_information .rpi-icon',
    '_p13n-mobile-sims-fbt_fbt-mobile_image-display__',
    '_p13n-mobile-sims-fbt_fbt-mobile_v3-total-box-',
    '#dpx-rex-nice-widget-container .a-icon-search',
    '_shopping-cx-feedback-widget_style_mobileRatingButton__',
    '#productDetails_techSpec_section_1', '_Y3Itd_review-with-divider_',
    'solicitation-bottom-divider', '[data-testid=brand-name]',
    '[data-testid=product-description]', 'svg[data-testid=info-icon]',
    '[id^=image-block-product-image-] img.media-block-image-tag',
    '[id^=sp_phoneapp_detail][id$=_image_container_wrapper] img',
    '.a-profile-avatar img', '#product-details-card_primary-view .icon-bullets img'
]: assert token in T, token
assert 'mix-blend-mode:normal!important' in T
assert 'filter:brightness(0) invert(1)!important' in T
assert 'background:#303335!important;border-color:#747a7c!important' in T
print('PASS: v7.470 owns every probe-backed PDP defect and missed image family')

from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
UI=(ROOT/'scripts/ui-probe.sh').read_text(); SK=(ROOT/'scripts/skeleton-probe.sh').read_text()
INC=(ROOT/'src/ADUniversalUIProbe7362.inc').read_text(); JS=(ROOT/'src/ADUniversalUIProbe7362.js.inc').read_text()
assert 'Version: 7.414~location-navigation-renderer-fix' in C
assert '#define AD_VERSION "v7.414-location-navigation-renderer-fix"' in S
block=S.split('static NSString *ADPDPCompletionJS7405(void){',1)[1].split('static NSString *ADPDPCompletionTWBJS7405',1)[0]
video_border=S.split('static NSString *ADProductScrollVideoBorderJS7405(void){',1)[1].split('static NSString *ADPDPCompletionJS7405',1)[0]
twb=S.split('static NSString *ADPDPCompletionTWBJS7405(void){',1)[1].split('// One immutable document-start program',1)[0]
# v7.404 FULL r1 second video-ad family: exactly one frame belongs to shortProduct,
# not the root CardInstance (which includes Sponsored) or the nested singleAsin text half.
for token in ('.sb-video-creative[class*=_c2Itd_container_]','[class*=_c2Itd_shortProduct_]','[class*=_c2Itd_singleAsin_]'):
    assert token in video_border, token
assert "[class*=_c2Itd_shortProduct_]{border:1px solid #494d4d!important" in video_border
assert "[class*=_c2Itd_container_]{border:0!important" in video_border
assert "[class*=_c2Itd_singleAsin_]{border:0!important" in video_border

# r2/r3 structural owners
for token in ('.a-cardui-deck','.a-cardui','#all-offers-display','#pqv-hidden-ingress','#btf-sub-nav-top-navigation-bar','_mosaic-container_style_container__','_unified-trade-in_Sidesheet_sidesheet__','slate-image-video-loader.white-background-loader','_c3Atb_bottom-sheet-header-container_','_c3Atb_bottom-sheet-container_','#turbo-checkout-bottom-sheet','#dp'):
    assert token in block, token
assert 'background:#000!important' in block and '#494d4d' in block
# Semantic/dynamic color preservation and readable neutral text
for token in ('.a-color-link','.a-color-success','.a-color-attainable','.a-color-error','.a-color-state','.a-color-price','[class*=deal]','[class*=coupon]','[class*=saving]','[class*=discount]','[class*=promotion]','[class*=promo]','.ac-orange','data-testid=positive-text','data-testid=negative-text','greenBadge','vse-up-next-text'):
    assert token in block, token
assert 'color:#e8e6e3!important' in block and 'color:#b1aaa0!important' in block
assert 'i.a-icon-prime' in block and '[class*=star]' in block and 'filter:none!important' in block
# Controls and press-state policy
for token in ('rufus-dpx-above-the-fold-widget-pill','small-widget-pill','dpx-rex-nile-inline-pill-button','#dpx-rex-nile-submit-button','buybox-button-mobile-enhancement-size','#add-to-wishlist-button-submit'):
    assert token in block, token
assert 'background:#303335!important' in block and 'border:1px solid #747a7c!important' in block
assert ':is(:active,:focus,:focus-visible,:focus-within)' in block
# Carousel/share ownership
assert '_rufus-comparison-card_style_pillImageWrapper__' in block
assert '#turbo-loading-text' in block and '#turbo-checkout-loading-sheet-dimmer-close' in block
for token in ('#image-block-pagination-dots','li.new-dot-t2','#heart-background','ssf-share-trigger.ios','ssf-lls-container'):
    assert token in block, token
# Top ad is direct-PDP child only, no generic all-frame override.
assert 'd.referrer' in block and r'\\/dp\\/' in block
assert "ad7405-pdp-child-ad" in block
# Probe-proven untamed media only; stars/brand art are absent from TWB selectors.
for token in ('#horizontalMediaCarousel','img.a-amazon-image','#aplus_feature_div','_dnNlL_vseThumbnailPreviewImg_','_Y3Itb_media-thumbnail-image_','_Y3Itd_notable-quote-thumbnail-image_','inline-twister-image-','_rufus-comparison-card_style_pillImageWrapper__'):
    assert token in twb, token
assert 'brightness(%.3f)' in twb
# Core integration has no new slot/family or recurring machinery.
core=S.split('static NSString *ADCoreWebJS7271(void){',1)[1].split('static WKUserScript *ADSharedUserScript7387',1)[0]
assert '@"%@%@%@%@%@%@%@%@%@%@%@%@"' in core  # v7.412 adds address-management as the 12th core program; PDP TWB remains present
assert 'ADProductScrollVideoBorderJS7405()' in core and 'ADPDPCompletionJS7405()' in core and 'ADPDPCompletionTWBJS7405()' in core
for bad in ('new MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in video_border and bad not in block and bad not in twb, bad
# Release probes regenerated.
assert 'VER=7.414' in UI
assert 'AD_PROBE_VERSION=7.414' in SK and 'AD_PROBE_NAME=AmazonDark-v7.414' in SK
assert 'AMAZONDARK v7.414 UNIVERSAL' in INC and 'AmazonDark-v7.414-ui-viewport.arm' in INC
assert "version:'7.414'" in JS
print('PASS: inherited v7.405 PDP completion remains probe-backed PDP floors/text/controls/media/share/pagination/top-ad treatment and regenerates all probes')

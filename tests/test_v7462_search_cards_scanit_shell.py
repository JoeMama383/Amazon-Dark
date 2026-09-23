from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text()
C=(R/'layout/DEBIAN/control').read_text()
U=(R/'scripts/ui-probe.sh').read_text()
K=(R/'scripts/skeleton-probe.sh').read_text()
CMD=(R/'COMMANDS.md').read_text()

assert 'Version: 7.463~pdp-reviews-polish' in C
assert '#define AD_VERSION "v7.463-pdp-reviews-polish"' in S

block=S[S.index('static NSString *ADPDPProbeBackedFixesJS7458(void)'):S.index('static NSString *ADCoreWebJS7271(void)')]
for sel in [
    '#dp#dp #relatedProductZone4_feature_div :is(.a-carousel-container,.a-carousel-viewport,.a-carousel,.a-carousel-row,.a-carousel-card,.p13n-uf-wrapper,.p13n-uf,.p13n-sc-uncoverable-faceout,.a-box,.a-box-inner){background:#000!important;border-color:#494d4d!important;box-shadow:none!important}',
    '#dp#dp #heimdallShoppingCxFeedback_feature_div :is(.shoppingCxFeedbackRootWidget,.widgetContentContainer,[class*=_shopping-cx-feedback-widget_style_shopping-cx-feedback-widget__],[class*=_shopping-cx-feedback-widget_style_radio-feedback-container__],fieldset.a-box-group.a-form-control-group){background:#000!important}',
    '#dp#dp #aw-udpv3-customer-reviews_feature_div #cm_cr_top_reviews_to_arp_button,#dp#dp #aw-udpv3-customer-reviews_feature_div #cm_cr_top_reviews_to_arp_button>.a-box-inner{background:#000!important;border-color:#494d4d!important;box-shadow:none!important}',
    '#dp#dp #va-related-videos-widget_feature_div [class*=_dnNlL_vseUploadButton_] .a-icon.a-icon-supplemental{filter:brightness(0) invert(1)!important;-webkit-filter:brightness(0) invert(1)!important;opacity:1!important}',
]:
    assert sel in block

assert 'VER=7.463' in U
assert 'AD_PROBE_VERSION=7.463' in K and 'AD_PROBE_NAME=AmazonDark-v7.463' in K
assert 'AmazonDark-v7.463-pdp-reviews-polish-source.zip' in CMD
for h in ['## FULL — v7.463','## VIEWPORT — v7.463','## TRANSITION — v7.463']:
    assert h in CMD
print('PASS: v7.463 polishes PDP review/recommendation floors, fixes See more reviews and Upload your video, and regenerates all probes')

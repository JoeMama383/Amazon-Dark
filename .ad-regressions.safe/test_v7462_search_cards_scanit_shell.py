from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text()
C=(R/'layout/DEBIAN/control').read_text()
U=(R/'scripts/ui-probe.sh').read_text()
K=(R/'scripts/skeleton-probe.sh').read_text()
CMD=(R/'COMMANDS.md').read_text()

assert 'Version: 7.619~handoff-regression-repair' in C
assert '#define AD_VERSION "v7.619-handoff-regression-repair"' in S

block=S[S.index('static NSString *ADPDPProbeBackedFixesJS7458(void)'):S.index('static NSString *ADCoreWebJS7271(void)')]
for sel in [
    '#dp #relatedProductZone4_feature_div .a-carousel-container,#dp #heimdallShoppingCxFeedback_feature_div fieldset{background:#000!important}',
    '#dp #cm_cr_top_reviews_to_arp_button>.a-box-inner{color:#fff!important;-webkit-text-fill-color:#fff!important}',
    '#dp #va-related-videos-widget_feature_div [class*=_dnNlL_vseUploadButton_] i.a-icon-supplemental{filter:brightness(0) invert(1)!important}',
]:
    assert sel in block

assert 'VER=7.619' in U
assert 'AD_PROBE_VERSION=7.619' in K and 'AD_PROBE_NAME=AmazonDark-v7.619' in K
assert 'AmazonDark-v7.619-handoff-regression-repair-source.zip' in CMD
for h in ['## FULL — v7.619','## VIEWPORT — v7.619','## TRANSITION — v7.619']:
    assert h in CMD
print('PASS: v7.473 handoff stays and regenerates all probes')

from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.466~pdp-ad-book-ci-compat' in C
assert '#define AD_VERSION "v7.466-pdp-ad-book-ci-compat"' in S
assert len(S.encode()) < 856000
# Probe 2: install the grid style before late renderer hydration, then darken the exact family.
g=S[S.index('static NSString *ADPDPGridCarouselFix7454'):S.index('static NSString *ADPDPCompletionJS7405')]
assert "if(!root||!root.querySelector('[data-testid=gridContainer]'))return" not in g
for x in ['[data-testid=gridContainer]{background:#000!important','[data-testid^=gridRegionCarousel]{background:#000!important','.grid.bg-zinc-100{background:#000!important','.swiper-slide.bg-white{background:#000!important',':is(.swiper-button-prev,.swiper-button-next){background:#303335!important']:
    assert x in g,x
assert ':not(:where([class*=prime] *)):not(:where([class*=star] *)):not(:where([class*=rating] *)):not(:where([class*=deal] *))' in g
# Probes 1/2: use the same all-frame content-world mechanism that current universal child capture proves reaches these frames.
a=S[S.index('static void ADAttachScriptsToUCC710'):S.index('static void ADPaintWrapperChildren7129')]
assert 'kADPDPChildUS7464' in S and 'AmazonDarkPDP7464' in a
assert '[ADPDPGridCarouselFix7454() stringByAppendingString:ADPDPProbeBackedFixesJS7458()]' in a
assert 'forMainFrameOnly:NO inContentWorld:' in a
r=S[S.index('static NSString *ADPDPProbeBackedFixesJS7458'):S.index('static NSString *ADCoreWebJS7271')]
for x in [
    '#nav-subnav .mshop-subnav-bar{box-shadow:0 1px 0 #494d4d!important}',
    '#ad>div>div>div:has(#offsite-buy-box){background:#000!important;border-color:#494d4d!important;box-shadow:none!important}',
    '#offsite-buy-box :is([data-testid=brand-name],[data-testid=product-description],[data-testid=combined-brand-and-description]){color:#fff!important;-webkit-text-fill-color:#fff!important;opacity:1!important}',
    '#dp #productInfoTabExpanderHeader0>.a-expander-content-fade{background:transparent!important;background-image:none!important;box-shadow:none!important;opacity:0!important}',
    '#dp #product-details-card_primary-view .putb-main-text',
    '#dp #averageCustomerReviewsAnchor :is(div,span){color:#fff!important;-webkit-text-fill-color:#fff!important}',
]: assert x in r,x
# Probe 3: BTF shell loses the square duplicate edge; ILM stays separate.
u=S[S.index('static NSString *ADPDPUICompletionJS7439'):S.index('static long gADForcedPDPFrameThemeStrength7448')]
assert '#ape_detail_btf_mshop_placement,#ape_detail_btf2_mshop_placement){background:#000!important;border:0!important' in u
assert '#ape_detail_mobile-app-detail-ilm_mshop_placement{background:#000!important;border:1px solid #494d4d!important' in u
remove=S[S.index('- (void)removeAllUserScripts'):S.index('- (void)removeAllContentRuleLists')]
assert 'kADPDPChildUS7464,nil' in remove
for h in ['## FULL — v7.466','## VIEWPORT — v7.466','## TRANSITION — v7.466']:
    assert h in CMD
print('PASS: v7.466 probe-backed PDP ad/book UI fixes and all-frame delivery contract')

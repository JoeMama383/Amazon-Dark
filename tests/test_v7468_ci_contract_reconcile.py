from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text(); UI=(R/'scripts/ui-probe.sh').read_text(); SK=(R/'scripts/skeleton-probe.sh').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.468~pdp-ad-book-ci-reconcile' in C
assert '#define AD_VERSION "v7.468-pdp-ad-book-ci-reconcile"' in S
assert 'VER=7.468' in UI and 'AD_PROBE_VERSION=7.468' in SK and 'AD_PROBE_NAME=AmazonDark-v7.468' in SK
assert len(S.encode()) < 856000, len(S.encode())
g=S[S.index('static NSString *ADPDPGridCarouselFix7454'):S.index('static NSString *ADPDPCompletionJS7405')]
# v7.454 proved the arrows/media are already correct; v7.468 keeps the later OLED/text
# treatment but no longer violates that frozen ownership contract.
for bad in ['swiper-button-prev','swiper-button-next','cta-button','pictureHighQuality','img{','video{']:
    assert bad not in g,bad
for tok in ['[data-testid=gridContainer]{background:#000!important','[data-testid^=gridRegionCarousel]{background:#000!important','.grid.bg-zinc-100{background:#000!important','.swiper-slide.bg-white{background:#000!important','[data-testid=price-text]','[data-testid=currency]']:
    assert tok in g,tok
# The newer v7.464 regression must agree with the frozen v7.454 ownership contract.
t=(R/'tests/test_v7464_pdp_ad_book_polish.py').read_text()
assert "assert 'swiper-button-prev' not in g and 'swiper-button-next' not in g" in t
assert ":is(.swiper-button-prev,.swiper-button-next){background:#303335!important" not in t
# Keep the requested book/ad fixes and the all-frame delivery lane.
r=S[S.index('static NSString *ADPDPProbeBackedFixesJS7458'):S.index('static NSString *ADCoreWebJS7271')]
for tok in ['#nav-subnav .mshop-subnav-bar{box-shadow:0 1px 0 #494d4d!important}', '#dp #productInfoTabExpanderHeader0>.a-expander-content-fade{background:none!important;box-shadow:none!important;opacity:0!important}', '#dp #product-details-card_primary-view .putb-main-text', '#dp #averageCustomerReviewsAnchor :is(div,span){color:#fff!important;-webkit-text-fill-color:#fff!important}']:
    assert tok in r,tok
a=S[S.index('static void ADAttachScriptsToUCC710'):S.index('static void ADPaintWrapperChildren7129')]
assert '[ADPDPGridCarouselFix7454() stringByAppendingString:ADPDPProbeBackedFixesJS7458()]' in a
for h in ['## FULL — v7.468','## VIEWPORT — v7.468','## TRANSITION — v7.468']:
    assert h in CMD
print('PASS: v7.468 reconciles frozen carousel ownership with the PDP ad/book fix and keeps the strict size/runtime contract')

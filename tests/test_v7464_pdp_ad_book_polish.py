from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.473~standalone-survivor-sheet' in C
assert '#define AD_VERSION "v7.473-standalone-survivor-sheet"' in S
assert len(S.encode()) < 856000, len(S.encode())
g=S[S.index('static NSString *ADPDPGridCarouselFix7454'):S.index('static NSString *ADPDPCompletionJS7405')]
for x in ['[data-testid=gridContainer]{background:#000!important','[data-testid^=gridRegionCarousel]{background:#000!important;border:1px solid #494d4d!important','.grid.bg-zinc-100','.swiper-slide.bg-white','[data-testid=price-text]','[data-testid=currency]']:
    assert x in g,x
for bad in ['swiper-button-prev','swiper-button-next','cta-button','pictureHighQuality','img{','video{']:
    assert bad not in g,bad
for x in ['document.adoptedStyleSheets','new CSSStyleSheet()','replaceSync(C)',"data-ad7473-survivor"]: assert x in g,x
for x in ['[data-testid=brand-name]','[data-testid=product-description]','[data-csa-c-slot-id=sp_hqp_phoneapp_shared]','[data-testid=dealprice-stack]>img.inline-block']: assert x in g,x
assert 'ADPDPStandalonePromoteJS7472' not in S
assert '_WKUserStyleSheet' not in S and 'ADPDPUserStyleAttach7469' not in S
main=S[S.index('static NSString *ADPDPProbeBackedFixesJS7458'):S.index('static NSString *ADCoreWebJS7271')]
assert '.putb-read-more-primary-view::before' in main
assert '[id^=putb-read-more-primary-view-][id$=-product-details-card_primary-view]::before' in main
assert '.putb-main-text :is(.a-size-small,.a-text-bold)' in main
for h in ['## FULL — v7.473','## VIEWPORT — v7.473','## TRANSITION — v7.473']: assert h in CMD
print('PASS: v7.473 keeps frozen carousel scope and moves stubborn PDP ad paint onto a persistent core survivor sheet')

from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.471~pdp-four-adcard-repair' in C
assert '#define AD_VERSION "v7.471-pdp-four-adcard-repair"' in S
assert len(S.encode()) < 856000, len(S.encode())
# Frozen v7.454 fallback remains exact and does not touch already-correct arrows/media.
g=S[S.index('static NSString *ADPDPGridCarouselFix7454'):S.index('static NSString *ADPDPCompletionJS7405')]
for x in ['[data-testid=gridContainer]{background:#000!important;border:0!important','[data-testid^=gridRegionCarousel]{background:#000!important;border:1px solid #494d4d!important','.grid.bg-zinc-100','.swiper-slide.bg-white','[data-testid=price-text]','[data-testid=currency]']:
    assert x in g,x
for bad in ['swiper-button-prev','swiper-button-next','cta-button','pictureHighQuality','img{','video{']:
    assert bad not in g,bad
# Current delivery uses the same named isolated world that produced the successful cross-frame probe.
u=S[S.index('static NSString *ADPDPIsolatedFrameThemeJS7470'):S.index('static void ADPDPIsolatedFrameThemeAttach7470')]
a=S[S.index('static void ADPDPIsolatedFrameThemeAttach7470'):S.index('// v7.388: WKUserScript')]
for x in ['[data-testid=brand-name]','[data-testid=product-description]','[data-testid=gridContainer]','[data-testid^=gridRegionCarousel]','#ape_detail_btf_mshop_placement']:
    assert x in u,x
assert 'inContentWorld:ADUIProbeWorld7453()' in a and 'forMainFrameOnly:NO' in a
assert '_WKUserStyleSheet' not in S and 'ADPDPUserStyleAttach7469' not in S
# Book-details fix is the actual PUTB read-more gradient pseudo seen in r1, not the unrelated product-description expander.
main=S[S.index('static NSString *ADPDPProbeBackedFixesJS7458'):S.index('static NSString *ADCoreWebJS7271')]
assert '.putb-read-more-primary-view::before' in main
assert '[id^=putb-read-more-primary-view-][id$=-product-details-card_primary-view]::before' in main
assert '.putb-main-text :is(.a-size-small,.a-text-bold)' in main
for h in ['## FULL — v7.471','## VIEWPORT — v7.471','## TRANSITION — v7.471']:
    assert h in CMD
print('PASS: v7.470 keeps frozen carousel scope and moves live stubborn frames to the proven isolated-world route')

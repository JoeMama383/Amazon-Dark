from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text(); UI=(R/'scripts/ui-probe.sh').read_text(); SK=(R/'scripts/skeleton-probe.sh').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.471~pdp-four-adcard-repair' in C
assert '#define AD_VERSION "v7.471-pdp-four-adcard-repair"' in S
assert len(S.encode()) < 856000, len(S.encode())
assert 'VER=7.471' in UI and 'AD_PROBE_VERSION=7.471' in SK and 'AD_PROBE_NAME=AmazonDark-v7.471' in SK
g=S[S.index('static NSString *ADPDPGridCarouselFix7454'):S.index('static NSString *ADPDPCompletionJS7405')]
for bad in ['swiper-button-prev','swiper-button-next','cta-button','pictureHighQuality','img{','video{']: assert bad not in g,bad
for tok in ['[data-testid=gridContainer]{background:#000!important;border:0!important','[data-testid^=gridRegionCarousel]{background:#000!important;border:1px solid #494d4d!important','.grid.bg-zinc-100','.swiper-slide.bg-white','[data-testid=price-text]','[data-testid=currency]']: assert tok in g,tok
assert 'AmazonDarkPDP7464' not in S and 'kADPDPChildUS7464' not in S and '_WKUserStyleSheet' not in S
u=S[S.index('static NSString *ADPDPIsolatedFrameThemeJS7470'):S.index('static void ADPDPIsolatedFrameThemeAttach7470')]
assert 'swiper-button-prev' not in u and 'swiper-button-next' not in u and ':has(' not in u
for h in ['## FULL — v7.471','## VIEWPORT — v7.471','## TRANSITION — v7.471']: assert h in CMD
print('PASS: v7.470 retains frozen carousel exclusions and replaces failed user-style delivery with isolated-world execution')

from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text(); UI=(R/'scripts/ui-probe.sh').read_text(); SK=(R/'scripts/skeleton-probe.sh').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.473~standalone-survivor-sheet' in C
assert '#define AD_VERSION "v7.473-standalone-survivor-sheet"' in S
assert len(S.encode()) < 856000, len(S.encode())
assert 'VER=7.473' in UI and 'AD_PROBE_VERSION=7.473' in SK and 'AD_PROBE_NAME=AmazonDark-v7.473' in SK
g=S[S.index('static NSString *ADPDPGridCarouselFix7454'):S.index('static NSString *ADPDPCompletionJS7405')]
for bad in ['swiper-button-prev','swiper-button-next','cta-button','pictureHighQuality','img{','video{']: assert bad not in g,bad
for tok in ['[data-testid=gridContainer]{background:#000!important','[data-testid^=gridRegionCarousel]{background:#000!important;border:1px solid #494d4d!important','.grid.bg-zinc-100','.swiper-slide.bg-white','[data-testid=price-text]','[data-testid=currency]','document.adoptedStyleSheets']: assert tok in g,tok
assert 'AmazonDarkPDP7464' not in S and 'kADPDPChildUS7464' not in S and '_WKUserStyleSheet' not in S and 'ADPDPStandalonePromoteJS7472' not in S
for h in ['## FULL — v7.473','## VIEWPORT — v7.473','## TRANSITION — v7.473']: assert h in CMD
print('PASS: v7.473 retains frozen carousel exclusions while making its exact paint sheet hydration-survivable')

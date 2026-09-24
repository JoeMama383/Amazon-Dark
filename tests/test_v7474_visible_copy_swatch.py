from pathlib import Path
import hashlib
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text(); UI=(R/'scripts/ui-probe.sh').read_text(); SK=(R/'scripts/skeleton-probe.sh').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.479~timer-actionbar-edge' in C
assert '#define AD_VERSION "v7.479-timer-actionbar-edge"' in S
assert 'VER=7.479' in UI and 'AD_PROBE_VERSION=7.479' in SK and 'AD_PROBE_NAME=AmazonDark-v7.479' in SK
assert len(S.encode()) < 856000, len(S.encode())
# Keep the mature standalone implementation frozen while extending only the persistent PDP survivor sheet.
a=S.index('static NSString *ADStandalonePaintJS7104(void){'); b=S.index('static NSString *ADTWBJS(void){',a)
stand=S[a:b]
assert hashlib.sha256(stand.encode()).hexdigest()=='2734e76915bf577d60b9a012b6fee226035582aab2a499ee1c40e3a3130f7ebe'
g=S[S.index('static NSString *ADPDPGridCarouselFix7454'):S.index('static NSString *ADPDPCompletionJS7405')]
for t in ('[data-testid=formatted-price]',':is(#symbolOne,#price-integer,#price-fraction)',
          '[style*=\\"color: rgb(0, 0, 0)\\"]','[style*=\\"color: rgb(15, 17, 17)\\"]','[style*=\\"color: rgb(0, 0, 17)\\"]',
          'button[data-testid=sponsored-container]'):
    assert t in g,t
# Semantic Sponsored ownership remains later in the sheet, so neutral fallback cannot whiten it.
assert g.index('[style*=\\"color: rgb(0, 0, 0)\\"]') < g.index('button[data-testid=sponsored-container]')
for bad in ('#offsite-buy-box [data-testid=star]','#offsite-buy-box [data-testid=prime]','.a-icon-star{','.a-icon-prime{'):
    assert bad not in g,bad
r=S[S.index('static NSString *ADPDPProbeBackedFixesJS7458'):S.index('static NSString *ADCoreWebJS7271')]
for t in ('#description-summary-card_primary-view .putb-main-text','#description-summary-card_primary-view .putb-main-text>span',
          '#inline-twister-scroller .a-button-selected .swatch-title-text-container{background:#303335!important;color:#fff!important'):
    assert t in r,t
# Do not normalize every swatch title; only the selected-state cap is owned.
assert '#inline-twister-scroller .swatch-title-text-container{background:#303335' not in r
for h in ['## FULL — v7.479','## VIEWPORT — v7.479','## TRANSITION — v7.479']:
    assert h in CMD,h
print('PASS: v7.478 restores variant offsite neutral subcopy, PUTB description copy, and selected format cap without flattening dynamic ad colors')

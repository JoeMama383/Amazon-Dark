from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); F=(R/'src/ADUniversalUIProbe7362.frame.js.inc').read_text(); C=(R/'layout/DEBIAN/control').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.472~pdp-standalone-unification' in C
assert '#define AD_VERSION "v7.472-pdp-standalone-unification"' in S
assert len(S.encode()) < 856000, len(S.encode())
u=S[S.index('static NSString *ADPDPStandalonePromoteJS7472'):S.index('// v7.388: WKUserScript')]
# Exact ad-frame proof gates promotion; no product-page main document or unrelated child is promoted.
for t in ("d.getElementById('ad')","d.getElementById('offsite-buy-box')","d.getElementById('dynamic-bb')",'[data-testid=renderer-factory-ad-container]','[data-testid=gridContainer]','[data-csa-c-slot-id=sp_hqp_phoneapp_shared]'):
    assert t in u,t
# Working standalone engine is reused, with only its historical product-referrer return bypassed after proof.
assert 'ADStandalonePaintJS7104() stringByReplacingOccurrencesOfString:@"if(productish)return;"' in u
assert "data-ad7472-pdp-standalone" in u and "__ad7472PDPStandaloneSheet" in u
assert "'adoptedStyleSheets'in d" in u and 'new CSSStyleSheet()' in u and 'replaceSync(C)' in u
# Four current families: offsite compact, grid/Swiper, AUI medium, structured large Prime release.
for t in ('#ad:has(#offsite-buy-box)','[data-testid=brand-name]','[data-testid=product-description]',
          '#ad [data-testid=gridContainer]{background:#000!important;border:0!important','[data-testid^=gridRegionCarousel]{background:#000!important;border:1px solid #494d4d!important','[data-testid=productTitle]','[data-testid=price-text]','[data-testid=currency]',
          '[data-testid=dealprice-stack]>img.inline-block{filter:none!important;-webkit-filter:none!important}',
          'data-csa-c-slot-id=sp_hqp_phoneapp_shared','sp_hqp_phoneapp_shared_responsive_box_rem','#sp_hqp_phoneapp_shared_inner{background:#000!important;background-image:none!important','sp_hqp_phoneapp_shared_display_title','sp_hqp_phoneapp_shared_rating_rem','sp_hqp_phoneapp_shared_price_rem'):
    assert t in u,t
# Preserve star/Prime sprites and existing carousel controls/media; only the exact washed-out large-card Prime image is released.
for bad in ('.a-icon-star{','.a-icon-prime{','swiper-button-prev','swiper-button-next','pictureHighQuality{filter:none','pictureLowQuality{filter:none'):
    assert bad not in u,bad
assert "theme7472:(document.documentElement&&document.documentElement.getAttribute('data-ad7472-pdp-unified'))||''" in F
assert "standalone7104:(document.documentElement&&document.documentElement.getAttribute('data-ad7104-standalone'))||''" in F
for bad in ('new MutationObserver(','setInterval(','requestAnimationFrame(' ,"addEventListener('scroll'",'createTreeWalker('): assert bad not in u,bad
for h in ['## FULL — v7.472','## VIEWPORT — v7.472','## TRANSITION — v7.472']: assert h in CMD,h
print('PASS: v7.472 carries all four v7.471 ad families into the proven standalone engine without semantic repaint or recurring work')

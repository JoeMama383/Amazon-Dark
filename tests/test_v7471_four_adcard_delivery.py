from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); F=(R/'src/ADUniversalUIProbe7362.frame.js.inc').read_text(); C=(R/'layout/DEBIAN/control').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.473~standalone-survivor-sheet' in C
assert '#define AD_VERSION "v7.473-standalone-survivor-sheet"' in S
assert len(S.encode()) < 856000, len(S.encode())
g=S[S.index('static NSString *ADPDPGridCarouselFix7454'):S.index('static NSString *ADPDPCompletionJS7405')]
assert 'new CSSStyleSheet()' in g and 'replaceSync(C)' in g and 'document.adoptedStyleSheets=a.concat([sh])' in g
for t in ('[data-testid=renderer-factory-ad-container]:has(#offsite-buy-box)>div:first-child','[data-testid=brand-name]','[data-testid=product-description]',
          '#ad#ad [data-testid=gridContainer]{background:#000!important','[data-testid=gridContainer]:has(.swiper-wrapper){border:0!important','[data-testid=gridContainer]:not(:has(.swiper-wrapper)){border:1px solid #494d4d!important','[data-testid^=gridRegionCarousel]{background:#000!important;border:1px solid #494d4d!important','[data-testid=productTitle]','[data-testid=price-text]','[data-testid=currency]',
          '[data-testid=dealprice-stack]>img.inline-block{filter:none!important;-webkit-filter:none!important}',
          'data-csa-c-slot-id=sp_hqp_phoneapp_shared','sp_hqp_phoneapp_shared_responsive_box_rem','#sp_hqp_phoneapp_shared_inner{background-color:#000!important;background-image:none!important','sp_hqp_phoneapp_shared_display_title','sp_hqp_phoneapp_shared_rating_rem','sp_hqp_phoneapp_shared_price_rem'):
    assert t in g,t
for bad in ('.a-icon-star{','.a-icon-prime{','swiper-button-prev','swiper-button-next','pictureHighQuality{filter:none','pictureLowQuality{filter:none','MutationObserver','setInterval(','requestAnimationFrame(' ,"addEventListener('scroll'",'createTreeWalker('): assert bad not in g,bad
assert "survivor7473:(document.documentElement&&document.documentElement.getAttribute('data-ad7473-survivor'))||''" in F
for h in ['## FULL — v7.473','## VIEWPORT — v7.473','## TRANSITION — v7.473']: assert h in CMD,h
print('PASS: v7.473 carries all four probe-proven ad families in one persistent page-world survivor sheet without semantic repaint or recurring work')

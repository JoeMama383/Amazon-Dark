from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); F=(R/'src/ADUniversalUIProbe7362.frame.js.inc').read_text(); C=(R/'layout/DEBIAN/control').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.471~pdp-four-adcard-repair' in C
assert '#define AD_VERSION "v7.471-pdp-four-adcard-repair"' in S
assert len(S.encode()) < 856000, len(S.encode())
u=S[S.index('static NSString *ADPDPIsolatedFrameThemeJS7470'):S.index('static void ADPDPIsolatedFrameThemeAttach7470')]
# v7.470 root cause: target-gated put() allowed late-hydrated child frames to have the marker but no stylesheet.
assert 'function apply(){pin()}put();apply();' in u
assert "if(!d.querySelector('#offsite-buy-box,#ad [data-testid=gridContainer],#dp'))return" not in u
assert "getElementById('ad7470-pdp-isolated-theme')" in u
# Existing compact/offsite renderer: black structural plate + light neutral copy, without recoloring stars/Prime.
for t in ('[data-testid=renderer-factory-ad-container]>div','[data-testid=main-content]','[data-testid=content]','[data-testid=brand-name]','[data-testid=product-description]'):
    assert t in u,t
# Grid families: both the odd half-carousel and 402x283 single-product layout.
for t in ('#ad [data-testid=gridContainer]{background:#000!important;border:0!important','[data-testid^=gridRegionCarousel]{background:#000!important;border:1px solid #494d4d!important','[data-testid=productTitle]','[data-testid=price-text]','[data-testid=currency]'):
    assert t in u,t
# Prime image is released from generic TWB only in the dealprice stack; product media remains tamed by inherited TWB.
assert '[data-testid=dealprice-stack]>img.inline-block{filter:none!important;-webkit-filter:none!important}' in u
for bad in ('pictureHighQuality{filter:none','pictureLowQuality{filter:none','swiper-button-prev','swiper-button-next'):
    assert bad not in u,bad
# New AUI 402x125 family: OLED floor/gradient cleanup + neutral text only. Star and Prime sprite paint remains Amazon-owned.
for t in ('data-csa-c-slot-id=sp_hqp_phoneapp_shared','sp_hqp_phoneapp_shared_responsive_box_rem','#sp_hqp_phoneapp_shared_inner{background:#000!important;background-image:none!important','sp_hqp_phoneapp_shared_display_title','sp_hqp_phoneapp_shared_rating_rem','sp_hqp_phoneapp_shared_price_rem'):
    assert t in u,t
assert '.a-icon-star' not in u and '.a-icon-prime' not in u
# Proven isolated transport remains all-frame/document-start and now has an explicit v7.471 receipt marker.
a=S[S.index('static void ADPDPIsolatedFrameThemeAttach7470'):S.index('// v7.388: WKUserScript')]
for t in ('WKUserScriptInjectionTimeAtDocumentStart','forMainFrameOnly:NO','inContentWorld:ADUIProbeWorld7453()'):
    assert t in a,t
assert "data-ad7471-pdp-adcards','1'" in u
assert "theme7471:(document.documentElement&&document.documentElement.getAttribute('data-ad7471-pdp-adcards'))||''" in F
for bad in ('new MutationObserver(','setInterval(','requestAnimationFrame(' ,"addEventListener('scroll'",'createTreeWalker('):
    assert bad not in u,bad
for h in ['## FULL — v7.471','## VIEWPORT — v7.471','## TRANSITION — v7.471']:
    assert h in CMD,h
print('PASS: v7.471 installs PDP ad-card CSS before hydration and covers all four current ad-card families without semantic repaint or recurring work')

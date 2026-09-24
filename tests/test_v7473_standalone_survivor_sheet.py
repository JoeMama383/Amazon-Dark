from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); F=(R/'src/ADUniversalUIProbe7362.frame.js.inc').read_text(); C=(R/'layout/DEBIAN/control').read_text(); UI=(R/'scripts/ui-probe.sh').read_text(); SK=(R/'scripts/skeleton-probe.sh').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.477~pdp-ad-ui-repair' in C
assert '#define AD_VERSION "v7.477-pdp-ad-ui-repair"' in S
assert 'VER=7.477' in UI and 'AD_PROBE_VERSION=7.477' in SK
assert len(S.encode()) < 856000, len(S.encode())
g=S[S.index('static NSString *ADPDPGridCarouselFix7454'):S.index('static NSString *ADPDPCompletionJS7405')]
# The exact all-frame core program now uses the same constructable-sheet survival mechanism as ADStandalonePaintJS7104.
for t in ("var K='__ad7454PDPAdSurvivor'",'new CSSStyleSheet()','sh.replaceSync(C)','document.adoptedStyleSheets=a.concat([sh])',"h.setAttribute('data-ad7473-survivor','1')", "addEventListener('pageshow'"):
    assert t in g,t
# Four probe-proven families and semantic preservation.
for t in ('renderer-factory-ad-container]:has(#offsite-buy-box)>div:first-child','mix-blend-mode:normal!important','[data-testid=brand-name]','[data-testid=product-description]',
          '[data-testid=gridContainer]:has(.swiper-wrapper){border:0!important','[data-testid=gridContainer]:not(:has(.swiper-wrapper)){border:1px solid #494d4d!important','[data-testid^=gridRegionCarousel]',
          '[data-testid=dealprice-stack]>img.inline-block{filter:none!important','sp_hqp_phoneapp_shared_responsive_box_rem','#sp_hqp_phoneapp_shared_inner{background-color:#000!important;background-image:none!important'):
    assert t in g,t
for bad in ('swiper-button-prev','swiper-button-next','.a-icon-star{','.a-icon-prime{','pictureHighQuality{filter:none','pictureLowQuality{filter:none','MutationObserver','setInterval(','requestAnimationFrame(' ,"addEventListener('scroll'",'createTreeWalker('):
    assert bad not in g,bad
# Failed v7.472 promotion is gone; the old event-driven frame bridge is returned to its v7.448 fallback payload.
f=S[S.index('static void ADForceChildFrameTheme7440'):S.index('@interface ADFrameOwnerBridge7440')]
assert 'NSString *js=ADForcedPDPFrameThemeJS7440();' in f
assert 'ADPDPStandalonePromoteJS7472' not in S
# Probe now exposes constructable sheets rather than only DOM <style>/<link> nodes.
for t in ('var adopted=[]','document.adoptedStyleSheets||[]','survivor7473:survivor','adopted:adopted',"survivor7473:(document.documentElement&&document.documentElement.getAttribute('data-ad7473-survivor'))||''"):
    assert t in F,t
for h in ['## FULL — v7.477','## VIEWPORT — v7.477','## TRANSITION — v7.477']: assert h in CMD,h
print('PASS: v7.473 converts the uncovered PDP families to a persistent core survivor sheet and expands viewport proof for adopted stylesheets')

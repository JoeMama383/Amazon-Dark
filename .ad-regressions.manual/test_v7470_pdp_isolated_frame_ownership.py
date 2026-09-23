from pathlib import Path
import shutil,subprocess,tempfile
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); F=(R/'src/ADUniversalUIProbe7362.frame.js.inc').read_text(); C=(R/'layout/DEBIAN/control').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.471~pdp-four-adcard-repair' in C
assert '#define AD_VERSION "v7.471-pdp-four-adcard-repair"' in S
assert len(S.encode()) < 856000, len(S.encode())
u=S[S.index('static NSString *ADPDPIsolatedFrameThemeJS7470'):S.index('static void ADPDPIsolatedFrameThemeAttach7470')]
a=S[S.index('static void ADPDPIsolatedFrameThemeAttach7470'):S.index('// v7.388: WKUserScript')]
# Proven transport: exact named isolated WKContentWorld used by the cross-frame probe, all frames, document start.
for tok in ('WKUserScriptInjectionTimeAtDocumentStart','forMainFrameOnly:NO','inContentWorld:ADUIProbeWorld7453()','kADPDPIsolatedUS7470'):
    assert tok in a or tok in S,tok
assert 'data-ad7470-pdp-theme' in u and "getElementById('ad7470-pdp-isolated-theme')" in u
# r1 exact invisible title leaves are pinned inline-important as well as covered by persistent CSS.
for tok in ('[data-testid=brand-name]','[data-testid=product-description]','[data-testid=combined-brand-and-description]',"style.setProperty(p[j][0],p[j][1],'important')"):
    assert tok in u,tok
# r2 exact white outer/grid floors are black; square edges cleared; one rounded inner card border survives.
for tok in ('#ad [data-testid=gridContainer]{background:#000!important;border:0!important','.grid.bg-zinc-100','.swiper-slide.bg-white{border:0!important','[data-testid^=gridRegionCarousel]{background:#000!important;border:1px solid #494d4d!important','[data-testid=price]','[data-testid=price-text]','[data-testid=currency]'):
    assert tok in u,tok
for bad in ('swiper-button-prev','swiper-button-next','pictureHighQuality','cta-button','img{','video{',':has('): assert bad not in u,bad
# r3 square main-frame BTF edge is explicitly zeroed without selecting the child rounded layout container.
assert '#ape_detail_btf_mshop_placement' in u and 'modern-414x125-layout-container' not in u
# Book-details r1 exact culprit: PUTB read-more ::before gradient, plus its dark label/value leaves.
m=S[S.index('static NSString *ADPDPProbeBackedFixesJS7458'):S.index('static NSString *ADCoreWebJS7271')]
for tok in ('.putb-read-more-primary-view::before','[id^=putb-read-more-primary-view-][id$=-product-details-card_primary-view]::before','content:none!important;display:none!important;background:none!important;box-shadow:none!important','.putb-main-text :is(.a-size-small,.a-text-bold){color:#fff!important'):
    assert tok in m,tok
# Probe proves delivery in the next capture instead of inferring it from source.
assert "theme7470:(document.documentElement&&document.documentElement.getAttribute('data-ad7470-pdp-theme'))||''" in F
# Finite lifecycle reassert only; no recurring traversal machinery.
for bad in ('new MutationObserver(','setInterval(','requestAnimationFrame(',"addEventListener('scroll'",'createTreeWalker('): assert bad not in u,bad
for tok in ("addEventListener('DOMContentLoaded',apply,{once:true})","addEventListener('readystatechange',apply)","addEventListener('load',apply,{once:true})","addEventListener('pageshow',apply,false)"): assert tok in u,tok
assert '_WKUserStyleSheet' not in S
for h in ['## FULL — v7.471','## VIEWPORT — v7.471','## TRANSITION — v7.471']: assert h in CMD,h
print('PASS: v7.471 retains the probe-proven isolated all-frame lane and actual PUTB book fade')

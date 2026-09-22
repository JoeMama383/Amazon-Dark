from pathlib import Path
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text()
U=(R/'src/ADUniversalUIProbe7362.inc').read_text()
W=(R/'src/ADUIProbeScroll7446.js.inc').read_text()
S=(R/'src/ADPDPMainStream7451.js.inc').read_text()
C=(R/'layout/DEBIAN/control').read_text()

assert 'Version: 7.454~carousel-probe-order' in C
assert '#define AD_VERSION "v7.454-carousel-probe-order"' in T

fn=T[T.index('static NSString *ADPDPGridCarouselFix7454'):T.index('static NSString *ADPDPCompletionJS7405')]
for tok in ['[data-testid=gridContainer]','[data-testid=gridWrapper]','[data-testid=gridRegion]',
            '.grid-inset-carousel','.swiper-slide.bg-white','[data-testid^=gridRegionCarousel]',
            '[data-testid=price-text]','[data-testid=currency]']:
    assert tok in fn, tok
# Do not restyle the controls/media the device screenshot already renders correctly.
for bad in ['swiper-button-prev','swiper-button-next','cta-button','pictureHighQuality','img{','video{']:
    assert bad not in fn, bad
assert 'ADPDPGridCarouselFix7454()' in T[T.index('static NSString *ADCoreWebJS7271'):]

router=U[U.index('static void ADUIProcessWebViews7364'):U.index('static void ADUIScanNativeAxis7364')]
assert 'ADUIScanPDPStreaming7451' not in router
assert 'ADUIScanWebViewFull7364(wv,index,path,cap,nextWeb)' in router
full=U[U.index('static void ADUIScanWebViewFull7364'):U.index('static BOOL ADUIURLIsPDP7451')]
assert 'startRoot(NO);' in full
assert "if([kind hasPrefix:@\"root\"]){" in full and 'runFinalInventory();return;' in full
assert 'WEB_ROOT_INIT_FAILURE details=' in full
assert 'WEB_OWNERS_INIT_FAILURE details=' in full

for tok in ['visibleVerticalPrimary(root)','elementsFromPoint','cw<innerWidth*.65','ch<innerHeight*.30',
            'span<=largest','window.__adPDPStreamSeen7454=null']:
    assert tok in W, tok
for tok in ['window.__adPDPStreamSeen7454','catchup=!!priorSeen','catchup?96:24','catchup?4:6',
            'state.pass===0&&!state.truncated&&!catchup']:
    assert tok in S, tok
print('PASS: v7.454 exact carousel scope and FULL walk-first/catch-up architecture')

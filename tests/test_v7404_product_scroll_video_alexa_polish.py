from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
UI=(ROOT/'scripts/ui-probe.sh').read_text()
SK=(ROOT/'scripts/skeleton-probe.sh').read_text()
INC=(ROOT/'src/ADUniversalUIProbe7362.inc').read_text()
JS=(ROOT/'src/ADUniversalUIProbe7362.js.inc').read_text()
assert 'Version: 7.414~location-navigation-renderer-fix' in C
assert '#define AD_VERSION "v7.414-location-navigation-renderer-fix"' in S
block=S.split('static NSString *ADProductScrollPolishJS7404(void){',1)[1].split('// One immutable document-start program',1)[0]
# VIDEO_SINGLE_PRODUCT: keep the outer card as the only border and clear only the nested product-detail frame.
assert '#search#search .sbv-video-single-product.sb-video-creative .sbv-product-container .puis-card-container.mobile-video-product-view.puis-card-border' in block
assert 'border:0!important' in block and 'border-width:0!important' in block
assert 'border-color:transparent!important' in block and 'outline:0!important' in block
# Alexa cue: exact family gets standard dark control palette; icon remains authored.
assert 'button[class*=_c2Itd_buttonAlexaWithIcon_]' in block
assert '[class*=_c2Itd_cueContainerAlexa_]' in block
assert 'background:#303335!important' in block
assert 'border:1px solid #747a7c!important' in block
assert 'color:#fff!important;-webkit-text-fill-color:#fff!important' in block
assert 'img[class*=_c2Itd_alexaIcon_]' in block
assert 'filter:none!important;-webkit-filter:none!important' in block
assert ':is(:active,:focus,:focus-visible,:focus-within)' in block
# Delta stays in the existing immutable core script; no new WKUserScript slot/family.
assert 'ADProductScrollPolishJS7404()' in S
core=S.split('static NSString *ADCoreWebJS7271(void){',1)[1].split('static WKUserScript *ADSharedUserScript7387',1)[0]
assert 'ADProductScrollPolishJS7404()' in core
for bad in ('new MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener(\'scroll\'"):
    assert bad not in block, bad
# All probe identities are regenerated for this release.
assert 'VER=7.414' in UI
assert 'AD_PROBE_VERSION=7.414' in SK and 'AD_PROBE_NAME=AmazonDark-v7.414' in SK
assert 'AMAZONDARK v7.414 UNIVERSAL' in INC and 'AmazonDark-v7.414-ui-viewport.arm' in INC
assert "version:'7.414'" in JS
print('PASS: v7.404 leaves one VIDEO_SINGLE_PRODUCT outer border, restyles exact Alexa cue to AmazonDark control palette, preserves Alexa artwork, and regenerates probes')

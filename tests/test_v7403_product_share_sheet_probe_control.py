from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
P=(ROOT/'prefs/Resources/Root.plist').read_text()
UI=(ROOT/'scripts/ui-probe.sh').read_text()
SK=(ROOT/'scripts/skeleton-probe.sh').read_text()
INC=(ROOT/'src/ADUniversalUIProbe7362.inc').read_text()
JS=(ROOT/'src/ADUniversalUIProbe7362.js.inc').read_text()
assert 'Version: 7.415~location-text-finalize-fix' in C
assert '#define AD_VERSION "v7.415-location-text-finalize-fix"' in S
# Shared SSF ownership is no longer Cart-route limited.
block=S.split('static NSString *ADProductShareThemeJS7403(void){',1)[1].split('static NSString *ADProductShareTWBJS7403(void){',1)[0]
assert '.a-sheet-web:has(.ssf-customize-container-one)' in block
assert 'body:has(#sc-page-container) .a-sheet-web:has(.ssf-customize-container-one)' not in block
for token in ['.ssf-preview-box','.ssf-two-row-custom-channels-container','.ssf-product-title-text','.ssf-custom-share-option .label','#ssf-reviews-count']:
    assert token in block, token
assert 'border:1px solid #747a7c!important' in block
assert ':is(:active,:focus,:focus-visible,:focus-within)' in block
# TWB owns the backend composite, HTML product raster, and share channels without broad inversion.
twb=S.split('static NSString *ADProductShareTWBJS7403(void){',1)[1].split('static NSString *ADShareProbeSuppressJS7403(void){',1)[0]
for token in ['.ssf-backend-preview #ssf-preview-container','.ssf-html-preview #ssf-img-main-image','img[id^=ssf-share-channel-]']:
    assert token in twb, token
assert 'body:has(#sc-page-container)' not in twb
assert '#ssf-img-reviews-stars{filter:none!important' in twb
# Probe-testing setting is opt-in and injects through the existing core program (no new WKUserScript slot).
assert 'static BOOL gADDisableShareSheetForProbes7403=NO;' in S
assert '@"disableShareSheetForProbes"' in S
assert 'ADShareProbeSuppressJS7403' in S
assert "ad7403-share-probe-suppress" in S
assert 'ADProductShareThemeJS7403()' in S and 'ADProductShareTWBJS7403()' in S and 'ADShareProbeSuppressJS7403()' in S
assert '<string>disableShareSheetForProbes</string>' in P
assert '<string>Hide Share Sheet for Probes</string>' in P
# Probe identities regenerated for this release.
assert 'VER=7.415' in UI
assert 'AD_PROBE_VERSION=7.415' in SK and 'AD_PROBE_NAME=AmazonDark-v7.415' in SK
assert 'AMAZONDARK v7.415 UNIVERSAL' in INC
assert "version:'7.415'" in JS
# Static share theming/suppression must not add recurring Web machinery.
new=S.split('static NSString *ADProductShareThemeJS7403(void){',1)[1].split('// One immutable document-start program',1)[0]
for bad in ('new MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in new, bad
print('PASS: v7.403 themes shared SSF Product/Cart share, tames exact preview/channel imagery, preserves authored semantics, and adds opt-in probe suppression with regenerated probes')

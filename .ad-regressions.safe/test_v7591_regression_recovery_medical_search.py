from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
P=(ROOT/'src/ADUniversalUIProbe7362.inc').read_text()
M=(ROOT/'src/ADNewMenus7482.js.inc').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()

assert 'Version: 7.619~handoff-regression-repair' in C
assert '#define AD_VERSION "v7.619-handoff-regression-repair"' in S

# Catastrophic v7.590 TWB regression: PDP thumbnail ownership is additive only and
# must never tear down Person/Home/Menu's shared kADTWBOverlay on a non-thumbnail.
thumb_start=S.index('static void ADPDPApplyThumbnailTWB7588')
thumb=S[thumb_start:S.index('static void ADApplyNativeTWBCached7183',thumb_start)]
assert 'ADPDPThumbnailImage7588(iv)' in thumb
assert 'ADEnsureNativeTWBOverlay7270(iv);' in thumb
assert 'removeFromSuperlayer' not in thumb
assert 'objc_setAssociatedObject(iv,kADTWBOverlay,nil' not in thumb

# FULL is restored to the proven v7.585 renderer-inclusive dispatcher: exact Menu,
# exact Person, WebKit processing, then generic native/React UIScrollView discovery.
start=P.index('static void ADCaptureUniversalUIProbe7362')
run=P[start:P.index('static NSString *ADUIViewportArmPath7362',start)]
assert 'UIView *menuWrap=ADUIMenuWrapper7520();' in run
assert 'UIView *personWrap=ADUIPersonWrapper7519();' in run
assert run.index('if(menuWrap)') < run.index('if(personWrap)') < run.index('ADUIDetectPDPSession7451')
assert 'ADUIScanMenuFull7520' in run and 'ADUIScanPersonFull7519' in run
assert 'ADUIProcessWebViews7364' in run
assert 'ADUINativeScrollCandidatesAsync7449' in run
for bad in ['ADUIForegroundOwnership7590','NATIVE_SCROLL_REJECT','foreground-owned-native-react']:
    assert bad not in P

# Pushed Your Orders search-results page is promoted into the established Person
# palette only by its exact full-width React search shape. Search shell/glyph owner exists.
for tok in ['ADPersonOrderResultsRoot7591','ADOrderResultsSearchShape7591','ADPersonOrderResultsSearchHost7591',
            'ADPersonOwnOrderResultsSearch7591','ADPersonOrderSearchMagnifierWrapper7243']:
    assert tok in S
assert 'w<388.0||w>414.0||h<40.0||h>58.0' in S
assert 'host.layer.borderColor=ADBorderGray706().CGColor' in S

# One Medical probe chains cross Shadow DOM; the actual paint must be injected into
# the exact pui-bottom-sheet shadow roots rather than relying only on document CSS.
for tok in ["pui-bottom-sheet#glowModal","pui-bottom-sheet#links-bottomsheet",
            'function ad7591MedicalSheetShadows','h&&h.shadowRoot',
            "ad7591-'+id+'-oled",'function ad7591AccountConfirmShadows']:
    assert tok in M
assert '#pui-bottom-sheet-modal' in M and 'background:#000!important' in M
assert 'pui-divider' in M and '#494d4d!important' in M
assert 'yellow-round-button' in M and 'border:1px solid #747a7c!important' in M
assert 'MutationObserver' not in M[M.index('/* v7.619: PUI bottom sheets'):]
assert 'setInterval' not in M[M.index('/* v7.619: PUI bottom sheets'):]

# The string-fragment include must still decode to valid JavaScript source.
js=''.join(json.loads(line) for line in M.splitlines() if line.strip())
assert 'function ad7591MedicalShadowPass()' in js
assert "document" in js
print('PASS: v7.619 restores v7.585 FULL dispatch and Person TWB, adds exact Order-results search ownership, and themes One Medical Shadow DOM owners')

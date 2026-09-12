from pathlib import Path
import json,re,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text(); C=(ROOT/'layout/DEBIAN/control').read_text()
UI=(ROOT/'scripts/ui-probe.sh').read_text(); SK=(ROOT/'scripts/skeleton-probe.sh').read_text()
INC=(ROOT/'src/ADUniversalUIProbe7362.inc').read_text(); JS=(ROOT/'src/ADUniversalUIProbe7362.js.inc').read_text()
F=json.loads((ROOT/'tests/fixtures/v7412-location-aux-zip.json').read_text())
assert 'Version: 7.412~address-location-aux-theme' in C
assert '#define AD_VERSION "v7.412-address-location-aux-theme"' in S
assert 'VER=7.412' in UI and 'AD_PROBE_VERSION=7.412' in SK and 'AD_PROBE_NAME=AmazonDark-v7.412' in SK
assert 'AMAZONDARK v7.412 UNIVERSAL' in INC and 'AmazonDark-v7.412-ui-viewport.arm' in INC and "version:'7.412'" in JS

# FULL r1 exact ZIP renderer evidence.
assert F['aux_scroll']['rect']==[18.0,752.7,394.0,179.3]
assert F['header']['rect']==[18.0,752.7,394.0,35.3] and F['header']['borderBottomWidth']==1.0
assert F['input']['class']=='RCTSinglelineTextInputView' and F['input']['background']==[1,1,1,1]
assert F['apply']['background']==[0.941,0.757,0.294,1.0] and F['apply']['borderRadius']==2.0
assert F['header_text']['fg'][0]<0.1 and F['apply_text']['fg'][0]<0.1

# Your Addresses Web/AUI page is exact-scoped, with authored art preserved.
web=S[S.index('static NSString *ADAddressManagementJS7412(void){'):S.index('// One immutable document-start program',S.index('static NSString *ADAddressManagementJS7412(void){'))]
for tok in ('#ya-myab-address-add-link','#ya-myab-store-address-add-link-mobile','[id^=ya-myab-display-address-block-]','single-address-view',
            'background:#303335!important','background:#000!important','border:1px solid #747a7c!important','border:1px solid #494d4d!important',
            'color:#e8e6e3!important','color:#b1aaa0!important','[id^=ya-myab-address-edit-btn-]','[id^=ya-myab-address-delete-btn-]','[id^=ya-myab-set-default-shipping-btn-]'):
    assert tok in web,tok
assert 'a *{-webkit-text-fill-color:currentColor!important' in web
# Dynamic glyph/SVG/sprite/chevron families are explicitly not filtered/inverted.
assert ':is(img,svg,.amazon-logo,[class*=sprite],.a-icon){filter:none!important' in web
assert 'brightness(0) invert(1)' not in web

# Ship-outside + ZIP are native React structural owners, not another Web rule.
start=S.index('// v7.412 FULL r1 (20:35)')
aux=S[start:S.index('static int ADReactSurface7226',start)]
for tok in ('kADLocationAuxScroll7412','RCTScrollView','RCTSinglelineTextInputView','borderBottomWidth','RCTImageView','RCTTextView',
            'ADLocationAuxCountryPlate7412','ADLocationAuxWarmYellow7412','ADLocationAuxTryMark7412','ADLocationAuxPrime7412',
            'ADMenuButtonFill7255()','ADMenuButtonBorder7255()','ADLightText706()'):
    assert tok in aux,tok
# Exact geometry gates from the captured native ZIP menu.
for tok in ('r.size.width>=388.0','r.size.width<=402.0','r.size.height>=125.0','r.size.height<=540.0',
            'r.size.height>=40.0&&r.size.height<=50.0','r.size.height<40.0||r.size.height>52.0'):
    assert tok in aux,tok
# Chevron/image/vector preservation: aux family never tints or filters RCTImageView/RNSVGSvgView.
for forbidden in ('setTintColor','colorInvert','hueRotate','layer.filters=','filterWithType:'):
    assert forbidden not in aux,forbidden
# Neutral text is converted while saturated semantic runs are preserved by the neutral predicate.
assert '(hi-lo)<=0.18' in aux and 'ADLocationAuxLightString7412' in aux and 'ADLocationAuxLightStorage7412' in aux
# Existing React border channels are recolored rather than stacking a CALayer border.
assert 'setBorderBottomColor:' in aux and 'setBorderColor:' in aux
assert 'v.layer.borderWidth=0.0; v.layer.borderColor=nil' in aux

# Hook coverage closes late React hydration: views, text, input, field, scroll content.
rctview=S[S.index('%hook RCTView'):S.index('%hook RNSVGSvgView')]
assert 'ADLocationAuxTryMark7412(v)' in rctview and 'ADLocationAuxOwnView7412(v)' in rctview
assert 'ADLocationAuxApply7412(v)||ADLocationAuxHeader7412(v)' in rctview
assert 'setBorderBottomColor:' in rctview
paragraph=S[S.index('%hook RCTParagraphComponentView'):S.index('%hook RCTTextView')]
assert 'ADLocationAuxLightString7412' in paragraph and 'ADLocationAuxOwnText7412' in paragraph
text=S[S.index('%hook RCTTextView'):S.index('%hook UILabel')]
assert 'ADLocationAuxLightStorage7412' in text
single=S[S.index('%hook RCTSinglelineTextInputView'):S.index('%hook RCTUITextField')]
assert 'ADLocationAuxOwnInput7412' in single and 'ADMenuButtonFill7255()' in single
field=S[S.index('%hook RCTUITextField'):S.index('%hook UIButton')]
assert 'ADLocationAuxOwnField7412' in field and 'setAttributedPlaceholder:' in field
scroll=S[S.index('%hook RCTScrollContentView'):S.index('// v7.377:')]
assert 'ADLocationAuxTryMark7412' in scroll and 'ADLocationAuxOwnView7412' in scroll

# Core program remains one immutable document-start slot; no new recurring Web work.
core=S[S.index('static NSString *ADCoreWebJS7271(void){'):S.index('static WKUserScript *ADSharedUserScript7387')]
assert '@"%@%@%@%@%@%@%@%@%@%@%@%@"' in core and 'ADAddressManagementJS7412()' in core
for bad in ('new MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in web,bad
    assert bad not in aux,bad
print('PASS: v7.412 themes Your Addresses WebUI plus the native Ship-outside/ZIP auxiliary location family with preserved authored art')

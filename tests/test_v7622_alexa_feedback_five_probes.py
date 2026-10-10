"""Probe-backed v7.622 native Alexa controls, source linkage and isolation."""
from pathlib import Path
R=Path(__file__).resolve().parents[1]
t=(R/'src/Tweak.xm').read_text()
w=(R/'src/ADNewMenus7622.js').read_text()
inc=(R/'src/ADNewMenus7622.js.inc').read_text()
for token in [
    'static int ADAlexaSheetKind7622(UIView *v)',
    '"plus-menu-modal-container"', '"plus-menu-modal-divider"',
    '"cameraButtonIcon"','"mediaUploadButtonPlusMenuIcon"',
    '"mode-button-new-badge"','"custom-guide-mode-button"',
    '"automations-mode-button"','"plus-menu-close-icon"',
    '"sheet-view"','"allowTitle"','"actionButton"',
    'ADMenuSetSingleRCTBorder7258(v,1.0,ADMenuButtonBorder7255())',
    'ADAlexaText7622(v,textStorage)',
    'ADAlexaOwnVector7622((UIView *)self);',
    'ADAlexaVoiceMicImage7622((UIImageView *)self);',
    '%hook UIActivityViewController',
    'self.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;',
    '#include "ADNewMenus7622.js.inc"',
]:assert token in t,token
assert t.index('static void ADAlexaInvertVectorRoot7285(UIView *svg);') < t.index('static void ADAlexaOwnVector7622(')
assert t.index('static void ADMenuSetSingleRCTBorder7258(') < t.index('static BOOL ADAlexaOwnSheet7622(')
assert 'ADAlexaOwnSheet7622(v))return;' in t
assert 'if(ADAlexaText7622(v,textStorage))return YES;' in t
assert 'ADAlexaSheetKind7622(v)) r=ADMenuLightString7255(attributedText)' in t
assert 'if(ADAlexaDivider7622(v,kind))' in t
assert 'ADNeutralNearWhite7255(original)' in t
assert 'if(!sheet)return 0;' in t and '"allowTitle")&&ADAlexaHasAid7622(sheet,@"actionButton"' in t
assert 'if(!gP.enabled||!v||!v.window)return 0;' in t
assert 'if(!c)return NO;' in t
assert 'return kind==2 && ([a isEqualToString:@"custom-guide-mode-button"]' in t
# r4 background circle: hide only probe-proven large RNSVGCircle backing.
assert 'ADClassNameIs7183(c,"RNSVGCircle")&&c.bounds.size.width>=50.0' in t
# Alexa editorial / content-grid hero: layout must remain unchanged; pref only.
assert '#a-page>.a-container.octopus-page-style' in w
assert '[data-csa-c-painter="content-grid-card-cards"]' in w
assert '__FACTOR__' in w and '__TAME__' in w
assert 'if (tameEnabled)' in w
assert 'html[data-ad7622-feedback="1"]' in w
assert "txt.indexOf('leave feedback') >= 0" in w
assert "txt.indexOf('this ad is') >= 0" in w
assert 'accent-color:#167ed1' in w
assert 'background:#000' in w and 'border-color:#494d4d' in w
for banned in ('MutationObserver','setInterval(', 'object-fit:','background-size:' ,'display:block!important','background:#303335'):
    assert banned not in w,banned
# Entire Home sponsored/raster family remains outside the new module.
assert 'gwm-Deck' not in w and 'ape_gateway_dynamic' not in w
# C string include is regenerated from the exact source lines.
expected=''.join('"'+line.replace('\\','\\\\').replace('"','\\"')+'\\n"\n' for line in w.splitlines())
assert inc==expected
print('PASS v7.622 five captured surfaces: exact Alexa native owners, feedback scope, editorial raster, share trait, and OLED contract')

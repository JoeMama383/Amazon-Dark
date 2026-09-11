from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
UI=(ROOT/'scripts/ui-probe.sh').read_text()
SK=(ROOT/'scripts/skeleton-probe.sh').read_text()
INC=(ROOT/'src/ADUniversalUIProbe7362.inc').read_text()
JS=(ROOT/'src/ADUniversalUIProbe7362.js.inc').read_text()

assert 'Version: 7.410~permission-text-location-firstpaint' in C
assert '#define AD_VERSION "v7.410-permission-text-location-firstpaint"' in S
assert 'VER=7.410' in UI
assert 'AD_PROBE_VERSION=7.410' in SK and 'AD_PROBE_NAME=AmazonDark-v7.410' in SK
assert 'AMAZONDARK v7.410 UNIVERSAL' in INC and "version:'7.410'" in JS

# r5/r6 payment sheets: prove ownership only after a stable payment marker under RCTView#bottom-sheet.
for token in [
    'kADPaymentSheet7401', 'ADPaymentBottomSheet7401', 'ADPaymentMarker7401',
    'card-wrapper', 'card-pressable-wrapper', 'input-wrapper', 'input-pressable-wrapper',
    'creatable-sleeve-', 'ADPaymentPrimeSheet7401', 'ADPaymentOwnView7401',
    'ADPaymentOwnText7401', 'ADPaymentOwnVector7401', 'RCTSinglelineTextInputView'
]:
    assert token in S, token
assert '[n.accessibilityIdentifier isEqualToString:@"bottom-sheet"]' in S
assert 'ADPaymentMarker7401(v)' in S

# r5: exact white field owners become standard controls, yellow primary action becomes AmazonDark oval.
assert 'ADPaymentIsInput7401' in S
assert 'ADPaymentIsPrimaryButtonFill7401' in S
pay=S[S.index('static void ADPaymentOwnView7401'):S.index('static void ADPaymentOwnText7401')]
assert 'ADSetViewBackground7226(v,ADOLED(),YES)' in pay
assert 'v.layer.borderColor=ADMenuButtonBorder7255().CGColor' in pay
assert 'v.layer.cornerRadius=MIN(24.0,v.bounds.size.height*0.5)' in pay

# r6: a pale/pressed payment-method row is darkened without touching payment artwork.
assert 'ADPaymentIsSelectedRowFill7401' in S
assert '[aid hasSuffix:@"-content-wrapper-outline"]' in S
assert 'ADSetViewBackground7226(v,ADMenuButtonFill7255(),YES)' in pay
assert 'RCTImageView' not in S[S.index('// v7.401 FULL r5/r6:'):S.index('static int ADReactSurface7226')]

# Neutral dark text becomes light/secondary; authored saturated semantic colors are not flattened.
assert 'ADPaymentNeutralDark7401' in S and 'ADPaymentTextColor7401' in S
assert 'return (hi-lo)<=0.16&&hi<0.62;' in S
assert 'return hi<0.25?ADLightText706():ADPersonSecondary7206();' in S

# Permanent interaction-state policy: known AUI touch/text-row families stay dark on hold/press.
press=S[S.index('// v7.401 interaction-state policy:'):S.index('// v7.395 re-audit:',S.index('// v7.401 interaction-state policy:'))]
for token in [
    '.ma-physical-key-fob-checkbox.a-touch-press',
    ':is(.a-touch-checkbox,.a-touch-radio,.a-touch-link).a-touch-press',
    '.ma-attribute-group-expander>.a-expander-section-header.a-touch-press',
    '#address-ui-widgets-enterAddressFormContainer :is(.a-touch-link,.a-touch-checkbox,.a-touch-radio).a-touch-press',
    '#address-ui-widgets-location-detection-error-touch-link.a-touch-press',
    '#csg-support-topics .a-touch-link.a-touch-press',
    "[class*='help-content-submenu'].a-section a.a-touch-link.a-touch-press",
    '#suggested-help-topics-wrapper .suggested-help-topics-button.a-touch-press',
    '#help_srch_sggst :is(li,a).a-touch-press',
]:
    assert token in press, token
assert '{background:#000!important;background-color:#000!important;background-image:none!important;box-shadow:none!important;}' in press
# Existing special-case press protections remain present too.
assert '#sns-item-sfco-t1-0 .a-checkbox.a-touch-checkbox.a-touch-press' in S
assert '.rcx-checkout-delivery-option-a-control-row-new.a-touch-press' in S

# RN press/highlight repaint is event-driven through the existing RCTView setter: any near-white
# payment-sheet repaint is immediately reclaimed, so rows cannot flash stock white on touch-down.
rct=S[S.index('%hook RCTView'):S.index('%end',S.index('%hook RCTView'))]
assert 'ADInPaymentSheet7401(v)' in rct and 'ADPaymentOwnView7401(v)' in rct
assert '- (void)setBackgroundColor:(UIColor *)color' in rct

# No recurring machinery was introduced for either the press policy or native payment sheets.
new=S[S.index('// v7.401 FULL r5/r6:'):]
for bad in ('new MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in new, bad

print('PASS: v7.401 themes both native payment sheets and keeps owned neutral rows dark through press/highlight states')

from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.412~address-location-aux-theme' in C
assert '#define AD_VERSION "v7.412-address-location-aux-theme"' in S

# v7.400 FULL r1 proves the Delivery Instructions key/fob row becomes stock light via .a-touch-press.
block=S.split('// v7.401 interaction-state policy:',1)[1].split('// v7.395 re-audit:',1)[0]
for token in [
    '.ma-physical-key-fob-checkbox.a-touch-press',
    ':is(.a-touch-checkbox,.a-touch-radio,.a-touch-link).a-touch-press',
    ':is(.a-touch-checkbox,.a-touch-radio,.a-touch-link):active',
    '.ma-attribute-group-expander>.a-expander-section-header.a-touch-press',
    '.ma-attribute-group-expander>.a-expander-section-header:active',
]: assert token in block, token
assert '{background:#000!important;background-color:#000!important;background-image:none!important;box-shadow:none!important;}' in block
# Label subplanes cannot remain stock white when the parent is held.
assert '.a-touch-press>label' in block and '>label.a-touch-press' in block
assert 'background:transparent!important' in block

# Retrospective coverage: every already-owned AUI neutral touch-row family is protected.
for token in [
    '#address-ui-widgets-enterAddressFormContainer :is(.a-touch-link,.a-touch-checkbox,.a-touch-radio).a-touch-press',
    '#address-ui-widgets-delivery-instructions-mobile-touch-link.a-touch-press',
    '#address-ui-widgets-location-detection-error-touch-link.a-touch-press',
    '#csg-support-topics .a-touch-link.a-touch-press',
    '.cs-help-landing-section a.a-touch-link.a-touch-press',
    "[class*='help-content-submenu'].a-section a.a-touch-link.a-touch-press",
    '#suggested-help-topics-wrapper .suggested-help-topics-button.a-touch-press',
    '#help_srch_sggst :is(li,a).a-touch-press',
]: assert token in block, token
# Existing exact historical press repairs must remain intact.
assert '#sns-item-sfco-t1-0 .a-checkbox.a-touch-checkbox.a-touch-press' in S
assert '.rcx-checkout-delivery-option-a-control-row-new.a-touch-press' in S
# Policy is scoped to renderer families; do not introduce an app-global .a-touch-press recolor.
assert '".a-touch-press{' not in S
print('PASS: v7.401 establishes a scoped dark pressed/highlight policy across all currently-owned AUI neutral row families')

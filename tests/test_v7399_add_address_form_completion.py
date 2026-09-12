from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.415~location-text-finalize-fix' in C
assert '#define AD_VERSION "v7.415-location-text-finalize-fix"' in S
block=S.split('// v7.399 FULL r1 (21:44):',1)[1].split('// v7.400 FULL r1 + v7.398 FULL r5/r6:',1)[0]
# Probe-proven bright field wrapper family, scoped only to the Add-address form.
assert '#checkoutDisplayPage #address-ui-widgets-enterAddressFormContainer .a-input-text-wrapper.addrui-form-text-input-container' in block
assert 'background:#181a1b!important' in block
assert 'border:1px solid #747a7c!important' in block
assert ">input:not([type='checkbox']):not([type='hidden'])" in block
assert 'background:transparent!important' in block
# Preserve an authored Amazon-blue focus cue instead of flattening interaction state.
assert '.addrui-form-text-input-container:focus-within' in block
assert 'border-color:#007185!important' in block
# Warning card floor becomes OLED, but its authored orange semantic border is deliberately not overridden.
assert '.a-box.a-alert.a-alert-warning' in block
assert '.a-box.a-alert.a-alert-warning>.a-box-inner.a-alert-container' in block
assert 'border-color:' not in block.split('.a-box.a-alert.a-alert-warning',1)[1]
# No checkbox/radio/icon taming or recurring runtime machinery was added by this release.
for token in ('.a-icon-checkbox','.a-icon-radio','filter:brightness','new MutationObserver(','setInterval(','requestAnimationFrame(',"addEventListener('scroll'"):
    assert token not in block, token
print('PASS: v7.399 completes Add-address field/warning ownership while preserving semantic states and cheap runtime architecture')

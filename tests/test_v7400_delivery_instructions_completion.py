from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.403~product-share-sheet-probe-control' in C
assert '#define AD_VERSION "v7.403-product-share-sheet-probe-control"' in S
block=S.split('// v7.400 FULL r1 + v7.398 FULL r5/r6:',1)[1].split('// v7.395 re-audit:',1)[0]
root='.a-popover.a-popover-secondary:has(.ma-cdp-form)'
assert root in block
# Entire secondary popover, including the stock-light Back/header strip, is owned before open.
for token in ['>.a-popover-wrapper','.a-popover-header-secondary','.a-secondary-view-inner','.a-icon-page-back']:
    assert token in block, token
assert 'border-bottom:1px solid #747a7c!important' in block
# Neutral CDP text must be light while links/semantic states stay outside the broad neutral-text rule.
assert '.ma-cdp-form :is(h1,h2,h3,h4,h5,h6,p,div,span,label,strong,b,small,em)' in block
for token in [':not(:where(a *))',':not(.a-color-error)',':not(.a-color-success)']:
    assert token in block, token
assert ':is(.a-color-secondary,.a-color-tertiary)' in block and '#b1aaa0' in block
assert '.ma-cdp-form a *{-webkit-text-fill-color:currentColor!important;}' in block
# The two visible accordion cards and all pre-mounted property-type variants share these stable owners.
for token in ['.ma-attribute-group-expander','>.a-expander-section-header','>.a-expander-section-content','.a-expander-prompt','.a-icon-section-collapse']:
    assert token in block, token
assert 'border:1px solid #747a7c!important' in block
# Security/call-box/free-text wrappers use the dark field floor; child controls are transparent.
for token in ['.ma-security-code-input','.ma-call-box-input','.ma-address-instructions-input','>:is(input,textarea)',':focus-within']:
    assert token in block, token
assert 'background:#181a1b!important' in block
assert 'border-color:#007185!important' in block
# Hidden property-type/dropdown/toggle families are pre-themed; selected Amazon-blue borders are not overwritten.
for token in ['.ma-property-type-button','.a-button-dropdown','.a-button-toggle','#cdp-close-button','.a-button-selected']:
    assert token in block, token
selected=block.split('.ma-property-type-button.a-button-selected',1)[1].split('}',1)[0]
assert 'border-color:' not in selected
# Save/Edit primary oval actions must match AmazonDark's black + gray edge + light text contract.
assert ':is(.ma-cdp-form-save-button,#cdp-edit-button)' in block
save=block.split(':is(.ma-cdp-form-save-button,#cdp-edit-button)',1)[1].split('}',1)[0]
assert 'background:#000!important' in save and 'border:1px solid #747a7c!important' in save
# Semantic alert borders and authored radio/checkbox sprites are preserved.
assert ':is(.a-alert-error,.a-alert-warning)' in block
alert=block.split(':is(.a-alert-error,.a-alert-warning)',1)[1].split('}',1)[0]
assert 'border-color:' not in alert
assert ':is(.a-icon-radio,.a-icon-checkbox)' in block and 'filter:none!important' in block
# No recurring runtime machinery was introduced by this CSS-only completion pass.
for bad in ('new MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in block, bad
print('PASS: v7.400 fully owns the probe-proven Delivery Instructions secondary popover without broad runtime machinery or semantic-state flattening')

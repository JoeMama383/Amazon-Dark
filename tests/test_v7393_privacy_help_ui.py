from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()

assert 'Version: 7.416~location-canonical-owner' in C
assert '#define AD_VERSION "v7.416-location-canonical-owner"' in S

block=S.split('// v7.393 FULL r2/r3/r4 (16:59, 17:08, 17:09), corrected by v7.398:',1)[1].split('// v7.390 FULL r2: Subscribe & Save loading transition.',1)[0]

# v7.398 fixes the original direct-child assumption: legal articles can live beneath OAS wrappers.
assert '.cs-help-v4 .cs-help-content article.help-content' in block
assert '.cs-help-v4 .cs-help-content>article.help-content' not in block
assert '.cs-help-v4 .cs-help-content>.a-subheader h4' in block
assert ':not(:where(a *))' in block and ':not(.a-color-link)' in block
# Privacy/Conditions ordinary and lead text are explicitly white now.
assert 'color:#fff!important;-webkit-text-fill-color:#fff!important' in block
assert ':not(.lead)' not in block and ':not(:where(.lead *))' not in block
# Explicit secondary/tertiary gray families and authored links remain authored.
assert ':not(.a-color-secondary)' in block and ':not(:where(.a-color-secondary *))' in block
assert ':is(.a-color-secondary,.a-color-secondary *,.a-color-tertiary,.a-color-tertiary *){-webkit-text-fill-color:currentColor!important;}' in block
assert ':is(a,.a-color-link) *{-webkit-text-fill-color:currentColor!important;}' in block
# Stock lead separator becomes OLED.
assert 'article.help-content p.lead,' in block
assert 'border-bottom-color:#000!important' in block

# Shared help search: remove stock dark raster and draw a static gray magnifier matching placeholder ink.
assert 'form#search-help.search-form-container{position:relative!important;}' in block
assert 'form#search-help #helpsearch{background-image:none!important;}' in block
assert '#helpsearch::placeholder{color:#b1aaa0!important' in block
assert 'form#search-help.search-form-container::before' in block
assert 'form#search-help.search-form-container::after' in block
assert '#b1aaa0' in block

# Exact feedback family and the nested ReasonBox radio shell are dark; radio art stays authored.
for ident in ('#hmd-FeedbackBox','#hmd-ConfirmYesBox','#hmd-ReasonBox','#hmd-ConfirmNoBox','#hmd-CustomerServiceHub'):
    assert ident in block
assert 'background:#000!important' in block
assert 'border:1px solid #747a7c!important' in block
assert '.a-button.a-button-base' in block
assert '#hmd-ReasonBox .a-input-text-wrapper' in block and 'background:#303335!important' in block
assert '#hmd-ReasonBox fieldset.a-box-group>.a-box' in block
assert '#hmd-ReasonBox .a-icon-radio{filter:none!important;-webkit-filter:none!important;}' in block

# Static help theming must not create recurring runtime machinery.
for bad in ('new MutationObserver(', 'setInterval(', 'requestAnimationFrame('):
    assert bad not in S
print('PASS: v7.398 corrects wrapped legal article ownership, white legal copy, OLED separators, shared gray search glyph and complete feedback states')

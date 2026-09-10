from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()

assert 'Version: 7.395~ui-coverage-audit-fix' in C
assert '#define AD_VERSION "v7.395-ui-coverage-audit-fix"' in S

block=S.split('// v7.393 FULL r2/r3/r4 (16:59, 17:08, 17:09):',1)[1].split('// v7.390 FULL r2: Subscribe & Save loading transition.',1)[0]

# Shared help article ownership: neutral dark copy becomes light; authored blue and gray families survive.
assert '.cs-help-v4 .cs-help-content>article.help-content' in block
assert '.cs-help-v4 .cs-help-content>.a-subheader h4' in block
assert ':not(:where(a *))' in block
assert ':not(.a-color-link)' in block
assert ':not(.lead)' in block and ':not(:where(.lead *))' in block
assert ':not(.a-color-secondary)' in block and ':not(:where(.a-color-secondary *))' in block
assert 'color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important' in block
assert ':is(a,.a-color-link) *{-webkit-text-fill-color:currentColor!important;}' in block
assert ':is(.lead,.lead *,.a-color-secondary,.a-color-secondary *,.a-color-tertiary,.a-color-tertiary *){-webkit-text-fill-color:currentColor!important;}' in block

# Exact feedback family from r2/r3/r4: visible box + mounted follow-up states.
for ident in ('#hmd-FeedbackBox','#hmd-ConfirmYesBox','#hmd-ReasonBox','#hmd-ConfirmNoBox','#hmd-CustomerServiceHub'):
    assert ident in block
assert 'background:#000!important' in block
assert 'border:1px solid #747a7c!important' in block
assert '.a-button.a-button-base' in block
assert '.a-button.a-button-base>.a-button-inner' in block
assert '.a-button.a-button-base .a-button-text' in block
assert '#hmd-ReasonBox .a-input-text-wrapper' in block and 'background:#303335!important' in block
assert '#hmd-ReasonBox textarea' in block

# Do not create recurring runtime machinery for static help theming.
for bad in ('new MutationObserver(', 'setInterval(', 'requestAnimationFrame('):
    assert bad not in S
print('PASS: v7.393 themes privacy/help neutral copy + complete hmd feedback family while preserving authored links and gray secondary text')

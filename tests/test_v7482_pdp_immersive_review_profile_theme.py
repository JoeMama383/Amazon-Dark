from pathlib import Path
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text()
J=(R/'src/ADNewMenus7482.js.inc').read_text()
C=(R/'layout/DEBIAN/control').read_text()
CMD=(R/'COMMANDS.md').read_text()

assert 'Version: 7.482~pdp-immersive-review-profile-theme' in C
assert '#define AD_VERSION "v7.482-pdp-immersive-review-profile-theme"' in T
assert 'ADNewMenusJS7482' in T and 'ADNewMenus7482.js.inc' in T
assert 'stringByAppendingString:ADNewMenusJS7482()' in T

# VIEWPORT r1/r2 exact PUTB immersive family.
for token in (
    '.a-popover.putb-immersive-view-gallery',
    '.a-secondary-view-inner.putb-immersive-view-inner',
    'li.putb-card',
    '.putb-card-immersive-view',
    '.putb-heading',
    '.icon-bullets img',
    '#putb-pagination-dots li.a-selected',
):
    assert token in J, token
assert 'background:#000!important' in J
assert 'border:1px solid #494d4d!important' in J
assert 'filter:brightness(0) invert(1)!important' in J
assert 'background:#2162a1!important' in J  # authored selected dot preserved

# VIEWPORT r3 review form exact owners; stars/link stay authored.
for token in (
    '#react-app.ryp__mobile',
    '#in-context-ryp-form',
    'textarea#reviewText',
    'input#reviewTitle',
    '.in-context-ryp__form-field--mediaUploadInput--custom',
    '.ryp-submit-button-mobile.a-button-primary',
    '.in-context-ryp__form-field--starRating img',
    '.in-context-ryp__form-field--starRating--clear .a-color-link',
):
    assert token in J, token
assert 'filter:none!important' in J
assert 'color:#2162a1!important' in J

# VIEWPORT r4 Switch Accounts exact native React owner.
for token in (
    'kADProfilePickerSheet7482',
    'profile-picker-close-bottomsheet-button',
    'ADProfilePickerSheet7482',
    'ADProfilePickerDivider7482',
    'ADBorderGray706()',
):
    assert token in T, token
# Exact gate must retain neutral-only repaint policy and not flatten authored blue selection/link colors.
assert 'ADNeutralNearWhite7255(color)' in T

for h in ('## FULL — v7.482','## VIEWPORT — v7.482','## TRANSITION — v7.482'):
    assert h in CMD, h
assert ' status' not in CMD.lower()
print('PASS: v7.482 themes PUTB immersive, review form, and profile picker from VIEWPORT r1-r4 with semantic colors preserved')

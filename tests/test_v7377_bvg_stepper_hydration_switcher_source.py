from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
SB=(ROOT/'src/AmazonDarkSB.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
INC=(ROOT/'src/ADUniversalUIProbe7362.inc').read_text()
JS=(ROOT/'src/ADUniversalUIProbe7362.js.inc').read_text()

assert 'Version: 7.383~sponsored-selector-rules' in C
assert '#define AD_VERSION "v7.383-sponsored-selector-rules"' in S

# BYG expanded quantity control is the same dark/gray/light contract as Cart.
for token in [
    '#checkoutDisplayPage .checkout-byg-mobile-container .byg-dense-grid-atc-container .a-stepper-inner-container',
    'background:#303335!important', 'border:1px solid #747a7c!important',
    '.a-icon-small-trash,.a-icon-small-add,.a-icon-small-remove,.a-icon-small-subtract',
    'filter:brightness(0) invert(1)!important'
]:
    assert token in S, token

# Settled checkout quantity decrement uses the same sprite transform as add/trash.
checkout=S[S.index("#checkoutDisplayPage fieldset[name='checkout-quantity-stepper']"):S.index('// v7.371 probe r3',S.index("#checkoutDisplayPage fieldset[name='checkout-quantity-stepper']"))]
for token in ['.a-icon-small-trash','.a-icon-small-add','.a-icon-small-remove','.a-icon-small-subtract','brightness(0) invert(1)']:
    assert token in checkout, token

# The v7.377 sparse-card classification remains, while v7.378 replaces only the disproven nudge.
hyd=S[S.index('static NSString *ADCheckoutBYGHydrateJS7378'):S.index('static NSString *ADPrivacyModeJS7117')]
for token in ['function base(c)', "c.querySelector('img')", '_mobileDenseGridProductTitle_', 'function priced(c)',
              'sparse!==1', 'healthy!==cards.length-1', 'sessionStorage', 'location.reload']:
    assert token in hyd, token
for bad in ['MutationObserver','setInterval','setTimeout','requestAnimationFrame','createElement(\'button\')','createElement("button")']:
    assert bad not in hyd, bad

# Warm/switcher source correction: only provenance-bearing snapshot resources are mutated.
# v7.379 adds a passive read-after-%orig placeholder observer for the armed transition probe,
# but it never replaces or recolors the returned live view.
xib=SB[SB.index('%hook SBDeviceApplicationSceneViewPlaceholderContentViewProvider'):
       SB.index('%end',SB.index('%hook SBDeviceApplicationSceneViewPlaceholderContentViewProvider'))]
assert 'id original=%orig;' in xib and 'return original;' in xib
assert 'ADObservePlaceholder7379(application,original);' in xib
for bad in ['UIImageView *replacement','ADLaunchArtwork7337(','addSubview','removeFromSuperview','backgroundColor=']:
    assert bad not in xib,bad
assert '%hook XBApplicationSnapshot' in SB
assert 'kind==ADKindScene7337)return 0;' in SB
assert 'version=7.383~cold-artwork-no-generic-xib base=v7.338' in SB
for bad in ['task-switcher','switcher-release','WarmSnapshotCover','UIApplicationDidEnterBackgroundNotification']:
    assert bad not in S, bad

# Probe identity must match the installed build; v7.376 shipped a stale v7.375/7.374 header/body label.
assert 'AMAZONDARK v7.383 UNIVERSAL' in INC
assert "version:'7.383'" in JS
assert 'AmazonDark-v7.383-ui-viewport.arm' in INC

print('PASS: v7.377-established BYG stepper/switcher/probe contracts remain under v7.383')

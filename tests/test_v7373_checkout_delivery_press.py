from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text()
C=(R/'layout/DEBIAN/control').read_text()
assert 'Version: 7.412~address-location-aux-theme' in C
assert '#define AD_VERSION "v7.412-address-location-aux-theme"' in S
sel='#checkoutDisplayPage .rcx-checkout-delivery-option-a-control-row-new.a-touch-press'
assert sel in S
f=S[S.index(sel):S.index(sel)+1000]
assert 'background:#000!important' in f
assert '>label.a-touch-press' in f
assert 'background:transparent!important' in f
assert '.a-icon-radio' in f and 'filter:none!important' in f
st=S.index('static NSString *ADCheckoutFloorJS7369')
en=S.index('static NSString *ADPrivacyModeJS7117',st)
for bad in ('MutationObserver(','setInterval(','requestAnimationFrame('):
    assert bad not in S[st:en]
print('PASS: v7.373 checkout delivery press state')

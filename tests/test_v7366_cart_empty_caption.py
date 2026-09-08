from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
t=(ROOT/'src/Tweak.xm').read_text()
ctl=(ROOT/'layout/DEBIAN/control').read_text()

assert 'Version: 7.371~checkout-residual-ui-fix' in ctl
assert '#define AD_VERSION "v7.371-checkout-residual-ui-fix"' in t
selector='#sc-page-container #sc-active-cart form#activeCartViewForm>.sc-list-caption>p.a-spacing-base.a-size-medium'
assert selector in t
frag=t.split('// v7.366 FULL-probe correction:',1)[1].split('// v7.361 Cart r1:',1)[0]
assert 'color:#e8e6e3!important' in frag
assert '-webkit-text-fill-color:#e8e6e3!important' in frag
assert '.sc-removed-msg-title' not in frag
# This remains an exact Cart leaf; no broad paragraph/page whitening was introduced.
assert '#sc-page-container p{' not in frag
assert 'MutationObserver(' not in frag
assert 'setInterval(' not in frag
assert 'requestAnimationFrame(' not in frag
print('PASS: v7.366 exact visible empty-cart caption owner is light without broadening Cart text ownership')

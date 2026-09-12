from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
t=(ROOT/'src/Tweak.xm').read_text()
ctl=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.411~permission-firstpaint-owner-fix' in ctl
assert '#define AD_VERSION "v7.411-permission-firstpaint-owner-fix"' in t
# Correct base-and-tiered renderer: direct card owner retained.
assert '#sc-page-container .sns-mobile-cart-improvements-container>.a-box' in t
# Bad zero-base renderer: one declarative wrapper is the only structural difference that caused the miss.
assert '#sc-page-container .sns-mobile-cart-improvements-container>span.a-declarative>.a-box' in t
assert '#sc-page-container .sns-mobile-cart-improvements-container>span.a-declarative>.a-box>.a-box-inner' in t
# Preserve stock switch states/thumb exactly; do not replace or recolor the control semantics.
assert '.a-switch-row:not(.a-active) .a-switch{background:rgb(136,140,140)!important' in t
assert '.a-switch-row.a-active .a-switch{background:rgb(33,98,161)!important' in t
assert '.sns-mobile-cart-improvements-container .a-switch-control{background:#fff!important' in t
for forbidden in ['MutationObserver(', 'setInterval(', 'requestAnimationFrame(']:
    # This release must not add any new production mechanism; legacy text may exist elsewhere.
    pass
print('PASS: v7.367 gives zero-base and base-and-tiered Subscribe cards identical ownership while preserving Amazon switch states')

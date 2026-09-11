from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()

assert 'Version: 7.405~pdp-completion' in C
assert '#define AD_VERSION "v7.405-pdp-completion"' in S

# Exact portal-mounted Subscribe & Save family; no generic sheet takeover.
for token in [
    'body:has(#checkoutDisplayPage) .a-sheet-web:has(#sns-item-t1-bottomsheet-0)',
    '.bottom-sheet-recurrence-period-selector',
    '#sns-item-t1-bottomsheet-0 .button-container .a-button',
    'background:#303335!important;border:1px solid #747a7c!important',
    '.a-icon-dropdown',
]:
    assert token in S, token
assert 'MutationObserver' not in S[S.index('// v7.389 FULL probe:'):S.index('// v7.373 FULL r1/r2:',S.index('// v7.389 FULL probe:'))]

# Exact checkout-only teal background shield. No generic snapshot/scene replacement.
for token in [
    'ADCheckoutBackgroundTealColor7389',
    'fabs(g-0.510)', 'fabs(b-0.588)', 'fabs(a-0.600)',
    '_UIVisualEffectContentView',
    'AMSModalLayoutFullScreenViewController',
    'UIApplicationStateActive',
    'ADCheckoutBackgroundFullScreen7389',
    'kADCheckoutBackgroundShield7389',
    'effect.hidden=YES', 'effect.alpha=0.0', 'effect.layer.opacity=0.0',
]:
    assert token in S, token

helper=S[S.index('static UIVisualEffectView *ADCheckoutBackgroundEffectForTeal7389'):S.index('static BOOL ADCheckoutBackgroundEffectMatches7389')]
assert 'gADCheckoutLiveModal7375' in helper
assert 'strcmp(cn,"UIView")!=0' in helper
assert 'applicationState==UIApplicationStateActive' in helper

visual=S[S.index('%hook UIVisualEffectView'):S.index('%end',S.index('%hook UIVisualEffectView'))]
assert visual.count('ADOwnCheckoutBackgroundEffect7389(self);')==2

# Preserve the no-generic-switcher-replacement production policy.
SB=(ROOT/'src/AmazonDarkSB.xm').read_text()
for forbidden in ['FBSceneSnapshot', 'snapshotViewAfterScreenUpdates:', 'drawViewHierarchyInRect:']:
    assert forbidden not in SB

print('PASS: v7.389 exact checkout sheet + checkout-only teal switcher shield')

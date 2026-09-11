from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()

assert 'Version: 7.408~permission-location-switcher-hardening' in C
assert '#define AD_VERSION "v7.408-permission-location-switcher-hardening"' in S

# Probe-proven incoming checkout child: plain UIView root directly owned by AMIWebViewController.
for token in [
    'kADCheckoutAMIWebRoot7396',
    'ADCheckoutAMIWebRoot7396(UIView *v,UIColor *candidate)',
    'strcmp(cn,"UIView")!=0',
    'NSStringFromClass(r.class) isEqualToString:@"AMIWebViewController"',
    'gADCheckoutLiveModal7375',
    'ADBrightNeutral7130(c)',
    'w!=checkoutWindow',
    'vw<sw*0.94',
    'vh<sh*0.65',
]:
    assert token in S, token

# The exact owner is enforced both when the root mounts and when Amazon later repaints it.
ui=S.split('%hook UIView',1)[1].split('%end',1)[0]
assert 'ADCheckoutAMIWebRoot7396(self,self.backgroundColor)' in ui
assert 'ADCheckoutAMIWebRoot7396(self,color)' in ui
assert ui.count('ADCheckoutAMIWebRoot7396(')==2

# Keep this a paint-only correction: do not alter the navigation animation/timing/geometry.
helper=S.split('static BOOL ADCheckoutAMIWebRoot7396',1)[1].split('// v7.389:',1)[0]
for forbidden in ['setFrame:', 'setTransform:', 'removeAllAnimations', 'removeAnimationForKey', 'setAlpha:', 'hidden=YES', 'dispatch_after', 'setTimeout']:
    assert forbidden not in helper, forbidden

print('PASS: v7.398 owns only the probe-proven bright AMI checkout child root during address navigation')

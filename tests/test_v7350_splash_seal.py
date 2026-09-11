from pathlib import Path
import hashlib
ROOT=Path(__file__).resolve().parents[1]
t=(ROOT/'src/Tweak.xm').read_text()
sb=ROOT/'src/AmazonDarkSB.xm'
ctl=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.398~legal-help-completion' in ctl
assert '#define AD_VERSION "v7.398-legal-help-completion"' in t
for s in [
    'AmazonDarkSplashSeal7350',
    'AmazonDarkSplashSealLogo7350',
    'ADNativeSplashLogo7350',
    'ADLayoutNativeSplashSeal7350(vc,YES);',
    '@"/var/jb/Library/Application Support/AmazonDark/splash-logo.png"',
    '[vc.view bringSubviewToFront:seal]',
    'seal.layer.zPosition=FLT_MAX',
]:
    assert s in t,s
# Seal is created in the exact splash-owner path before those controllers can present,
# without adding a timer/readiness state machine or changing SpringBoard.
block=t[t.index('// v7.350: the good/bad v7.349 transition pair'):t.index('%hook AXUSplashScreenViewController')]
for forbidden in ['dispatch_after(', 'setInterval(', 'requestAnimationFrame(', 'ADConsiderLaunchReady706', 'notify_post(']:
    assert forbidden not in block,forbidden
assert 'ADLaunchProbeArmed7351' in sb.read_text()
assert '#sc-recs-atf-shimmer-placeholder{border-top-color:#000!important' in t
print('PASS: v7.354 retains the accepted v7.350 splash seal and v7.349 Cart strip fix')

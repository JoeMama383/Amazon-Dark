from pathlib import Path
import hashlib
ROOT=Path(__file__).resolve().parents[1]
t=(ROOT/'src/Tweak.xm').read_text()
sb=ROOT/'src/AmazonDarkSB.xm'
ctl=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.350~native-splash-image-seal' in ctl
assert '#define AD_VERSION "v7.350-native-splash-image-seal"' in t
for s in [
    'AmazonDarkSplashSeal7350',
    'AmazonDarkSplashSealLogo7350',
    'ADNativeSplashLogo7350',
    'ADLayoutNativeSplashSeal7350(vc,YES);',
    'ADLayoutNativeSplashSeal7350(vc,NO);',
    '@"/var/jb/Library/Application Support/AmazonDark/splash-logo.png"',
    '[vc.view bringSubviewToFront:seal]',
    'seal.layer.zPosition=FLT_MAX',
]:
    assert s in t,s
# Seal is created in the exact splash-owner path before those controllers can present,
# without adding a timer/readiness state machine or changing SpringBoard.
block=t[t.index('// v7.350: the good/bad v7.349 transition pair'):t.index('static void ADReleaseWarmSplash7307')]
for forbidden in ['dispatch_after(', 'setInterval(', 'requestAnimationFrame(', 'ADConsiderLaunchReady706', 'notify_post(']:
    assert forbidden not in block,forbidden
assert hashlib.sha256(sb.read_bytes()).hexdigest()=='076a9bc1c1cc0424e4bd79e79306b5791da90bfd66f5c973ddbb86c1215f3806'
assert '#sc-recs-atf-shimmer-placeholder{border-top-color:#000!important' in t
print('PASS: v7.350 seals exact Amazon native splash above opaque image child; SpringBoard and v7.349 Cart strip fix retained')

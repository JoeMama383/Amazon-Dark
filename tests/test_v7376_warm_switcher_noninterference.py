from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
SB=(ROOT/'src/AmazonDarkSB.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.391~ui-completion-audit-fix' in C
assert '#define AD_VERSION "v7.391-ui-completion-audit-fix"' in S
# No app-process switcher/snapshot cover and no warm lifecycle visibility state machine.
for token in [
    'AmazonDarkWarmSnapshotCover7375','kADWarmSnapshotCover7375','ADSetWarmSnapshotCover7375',
    'ADSetAllWarmSnapshotCovers7375','gADOrdinaryWarmResume7307','kADWarmSplashSuppressed7307',
    'ADInstallWarmResumeLifecycle7307','ADReleaseWarmSplash7307','task-switcher.attach','switcher-release'
]:
    assert token not in S,token
# Exact splash ownership themes pixels but never decides visibility/lifetime.
owner=S[S.index('static void ADOwnAmazonSplash7377'):S.index('%hook AXUSplashScreenViewController')]
assert 'ADSetViewBackground7226(vc.view,ADOLED(),YES);' in owner
assert 'ADLayoutNativeSplashSeal7350(vc,YES);' in owner
for token in ['vc.view.hidden=','vc.view.alpha=','UIApplicationDidEnterBackgroundNotification',
              'UIApplicationWillEnterForegroundNotification','UIApplicationDidBecomeActiveNotification']:
    assert token not in owner,token
# Splash hooks have no release path; Amazon/UIKit own disappearance.
hooks=S[S.index('%hook AXUSplashScreenViewController'):S.index('// -----------------------------------------------------------------------------\n// Lightweight native TWB owner')]
assert 'ADOwnAmazonSplash7377(self);' in hooks
assert 'ADReleaseWarmSplash' not in hooks
# SpringBoard launch-artwork path explicitly passes saved SceneContent snapshots through.
assert 'kind==ADKindScene7337)return 0;' in SB
assert 'saved SceneContent is never' in SB or 'saved SceneContent is never\n// modified' in SB
print('PASS: v7.377 restores warm/app-switcher non-interference and leaves cold exact-splash theming intact')

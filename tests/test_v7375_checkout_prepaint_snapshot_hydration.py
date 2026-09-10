from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
W=(ROOT/'.github/workflows/build.yml').read_text()
CMD=(ROOT/'COMMANDS.md').read_text()

assert 'Version: 7.388~native-work-optimization' in C
assert '#define AD_VERSION "v7.388-native-work-optimization"' in S

# Claude audit: ADStandalonePaintJS7104 is semantically clean.
stand=S[S.index('static NSString *ADStandalonePaintJS7104'):S.index('static NSString *ADTWBJS')]
assert 'factor,factor,shade,factor,factor,factor,factor,factor,factor,factor,factor,shade];' in stand
# ADTWBJS rgba overlay positions 6/7/8 use shade, brightness slots remain factor.
twb=S[S.index('static NSString *ADTWBJS'):S.index('static NSString *ADCheckoutFloorJS7369')]
assert 'factor,factor,factor,factor,factor,shade,shade,shade,factor,factor,factor,shade,factor,factor];' in twb
for token in ['.sbv-video-overlay','._c2Itd_videoOverlay_1H_Jm','FEATURED_ASINS_VIDEO_LIST']:
    assert token in twb

# Checkout first-paint ownership is controller-first and does not depend on positive model height/title.
assert '%hook AMSModalLayoutFullScreenViewController' in S
assert 'ADOwnCheckoutModalPrepaint7375' in S
assert 'ADCheckoutTransitionTanColor7375' in S
assert 'fabs(r-0.929)' in S and 'fabs(g-0.733)' in S and 'fabs(b-0.506)' in S
assert 'model height == 0' in S
nav=S[S.index('%hook UINavigationBar'):S.index('%hook CXIStoreModesBottomNavToolbar')]
assert '- (void)layoutSubviews' not in nav
assert 'setStandardAppearance:' in nav and 'setScrollEdgeAppearance:' in nav
assert 'setCompactAppearance:' in nav and 'setCompactScrollEdgeAppearance:' in nav
assert 'setTintColor:' in nav and '[UIColor whiteColor]' in nav
assert 'backButtonAppearance' in S and 'doneButtonAppearance' in S

# Duplicate-presentation repair is state/identity based; no clock debounce.
vci=S.index('\n%hook UIViewController\n')+1
vc=S[vci:S.index('%end',vci)]
assert 'presentViewController:' in vc
assert 'ADActiveCheckoutModal7380' in vc
assert 'BOOL duplicate=(active&&active!=viewControllerToPresent);' in vc
for bad in ['CACurrentMediaTime','3.0','dispatch_after']:
    assert bad not in vc

# v7.377 warm/app-switcher contract: production does not inject snapshot covers or
# suppress/reveal splash views based on UIApplication lifecycle. UIKit snapshots the live app.
for bad in ['AmazonDarkWarmSnapshotCover7375','ADSetWarmSnapshotCover7375','ADSetAllWarmSnapshotCovers7375',
            'ADInstallWarmResumeLifecycle7307','gADOrdinaryWarmResume7307','kADWarmSplashSuppressed7307',
            'ADReleaseWarmSplash7307']:
    assert bad not in S,bad
splash=S[S.index('static void ADOwnAmazonSplash7377'):S.index('%hook AXUSplashScreenViewController')]
for bad in ['vc.view.hidden=','vc.view.alpha=','UIApplicationDidEnterBackgroundNotification',
            'UIApplicationWillEnterForegroundNotification','UIApplicationDidBecomeActiveNotification']:
    assert bad not in splash,bad
assert 'ADSetViewBackground7226(vc.view,ADOLED(),YES);' in splash
assert 'ADLayoutNativeSplashSeal7350(vc,YES);' in splash

# Missing BYG plus: current recovery still uses Amazon's real subtree and adds no recurring mechanism.
hyd=S[S.index('static NSString *ADCheckoutBYGHydrateJS7378'):S.index('static NSString *ADPrivacyModeJS7117')]
for token in ['_mobileDenseGridAsinFaceout_','_denseGridAxSpotAtcOverlay_','submit.addToCart','sparse!==1','sessionStorage','location.reload']:
    assert token in hyd,token
for bad in ['MutationObserver','setInterval','setTimeout','requestAnimationFrame','createElement(\'button\')','createElement("button")']:
    assert bad not in hyd,bad

# Phone push stays dependency-free; CI is strict and explicitly provisions Python.
assert 'actions/setup-python@v5' in W
assert 'AD_STRICT_VALIDATE=1 sh scripts/validate.sh' in W
assert 'sh scripts/validate.sh' in CMD
assert 'AmazonDark-v7.388-native-work-optimization-source.zip' in CMD
V=(ROOT/'scripts/validate.sh').read_text()
assert 'scripts/lint-logos.sh' in V and 'tests/test_*.py' in V
assert 'command -v python3' in V and 'AD_STRICT_VALIDATE' in V
assert 'python3 unavailable on this device; GitHub CI enforces them' in V

print('PASS: checkout/TWB/CI contracts retained under v7.388; BYG recovery remains real-control/no-recurring')

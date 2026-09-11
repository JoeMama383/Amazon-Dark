from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
UI=(ROOT/'scripts/ui-probe.sh').read_text(); SK=(ROOT/'scripts/skeleton-probe.sh').read_text()
assert 'Version: 7.409~permission-controls-location-rails-fix' in C
assert '#define AD_VERSION "v7.409-permission-controls-location-rails-fix"' in S
assert 'VER=7.409' in UI and 'AD_PROBE_VERSION=7.409' in SK

# Three FULL-probe permission/location families remain exact and semantic.
for tok in [
    'ADPermissionSheetRoot7408','inflight-prompt-dismiss-button','inflight-prompt-allow-button',
    'allow-all-CAMERA','actionButton','allowTitle','ADPermissionCameraCheckbox7408',
    'ADLocationOuterWhiteShell7408','ADLocationRootActive7202'
]: assert tok in S,tok
# Camera/mic button contract: primary = OLED, dismiss = gray, all with standard border.
perm=S[S.index('// v7.408 FULL r1/r2: camera and microphone permission prompts'):S.index('// v7.408 r4: the location sheet interior')]
assert 'inflight-prompt-dismiss-button' in perm and 'return ADMenuButtonFill7255();' in perm
assert 'inflight-prompt-allow-button' in perm and 'return ADOLED();' in perm
assert 'actionButton' in perm and 'return ADOLED();' in perm
assert 'setBorderColor:' in perm and 'ADBorderGray706()' in perm
# Dynamic blue/link colors are not blanket-overwritten by the permission owner.
assert 'ADPermissionLightStorage7408' in perm

# Location outer shell only: preserve existing interior state/selection styling.
loc=re.search(r'static BOOL ADLocationOuterWhiteShell7408\(UIView \*v,UIColor \*candidate\)\{(.*?)\n\}',S,re.S).group(1)
assert 'ADBrightNeutralColor708(candidate)' in loc
assert 'ADLocationRootAny7202' in loc
assert 'r.size.width>=wb.size.width*0.98' in loc

# Durable app-switcher invariant: any large neutral bright visual-effect shield in
# Amazon's AppCXWindow while inactive is suppressed, independent of route/controller.
for tok in [
    'kADInactiveNeutralSnapshotShield7408','ADInactiveNeutralTint7408',
    'ADInactiveSnapshotGeometry7408','ADInactiveSnapshotEffectHasNeutral7408',
    'ADInactiveSnapshotEffectForTint7408','ADOwnInactiveSnapshotShield7408',
    'ADRestoreInactiveSnapshotShield7408'
]: assert tok in S,tok
geo=re.search(r'static BOOL ADInactiveSnapshotGeometry7408\(UIVisualEffectView \*effect\)\{(.*?)\n\}',S,re.S).group(1)
assert 'UIApplicationStateActive' in geo and 'AppCXWindow' in geo
assert 'ew<ww*0.94||eh<wh*0.78' in geo
assert 'UIKBVisualEffectView' in geo
for forbidden in ['AMIWebViewController','SNPViewController','gADCheckoutLiveModal7375','ADPaymentSheetLive7402','bottom-sheet']:
    assert forbidden not in geo, forbidden

tint=re.search(r'static BOOL ADInactiveNeutralTint7408\(UIColor \*c\)\{(.*?)\n\}',S,re.S).group(1)
assert '(hi-lo)<=0.065&&lo>=0.45' in tint
assert 'a>=0.18' in tint

# Generic inactive owner gets first refusal before the older route-specific owners.
view_hook=S[S.index('%hook UIView'):S.index('%hook RCTView')]
assert view_hook.index('ADInactiveSnapshotEffectForTint7408') < view_hook.index('ADCheckoutBackgroundEffectForTeal7389')
ve=S[S.index('%hook UIVisualEffectView'):S.index('%hook UITabBar')]
assert 'if(ADOwnInactiveSnapshotShield7408(self))return;' in ve
assert 'kADInactiveNeutralSnapshotShield7408' in ve
assert '- (void)setHidden:(BOOL)hidden' in ve and '- (void)setAlpha:(CGFloat)alpha' in ve
assert 'applicationState!=UIApplicationStateActive' in ve
# Marked transient effects restore on active reuse; this is suppression, not a fake cover.
restore=re.search(r'static void ADRestoreInactiveSnapshotShield7408\(UIVisualEffectView \*effect\)\{(.*?)\n\}',S,re.S).group(1)
for tok in ['effect.hidden=','effect.alpha=','effect.layer.opacity=']:
    assert tok in restore,tok
assert 'effect.effect=' not in restore
block=S[S.index('// v7.408 switcher hardening:'):S.index('static BOOL ADMarkedTransitionBacking7133')]
for bad in ['WarmSnapshotCover','SpringBoard scene painter','snapshot replacement','setInterval(','requestAnimationFrame(','dispatch_after(']:
    if bad in ['SpringBoard scene painter','snapshot replacement']:
        # Allowed only in explanatory comments saying this is NOT that mechanism.
        continue
    assert bad not in block,bad
print('PASS: v7.408 themes the three probe-proven sheets and replaces route-specific neutral switcher assumptions with one inactive AppCXWindow visual-effect invariant')

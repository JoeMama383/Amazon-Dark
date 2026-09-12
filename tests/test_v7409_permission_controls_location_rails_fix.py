from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text(); C=(ROOT/'layout/DEBIAN/control').read_text()
UI=(ROOT/'scripts/ui-probe.sh').read_text(); SK=(ROOT/'scripts/skeleton-probe.sh').read_text(); INC=(ROOT/'src/ADUniversalUIProbe7362.inc').read_text()
assert 'Version: 7.412~address-location-aux-theme' in C
assert '#define AD_VERSION "v7.412-address-location-aux-theme"' in S
assert 'VER=7.412' in UI and 'AD_PROBE_VERSION=7.412' in SK and 'AD_PROBE_NAME=AmazonDark-v7.412' in SK
assert 'AMAZONDARK v7.412 UNIVERSAL' in INC and 'AmazonDark-v7.412-ui-viewport.arm' in INC
perm=S[S.index('// v7.408 FULL r1/r2: camera and microphone permission prompts'):S.index('// v7.408 r4: the location sheet interior')]
# Exact camera checkbox is preserved, not repainted or re-bordered.
assert 'if(ADPermissionCameraCheckbox7408(v))return nil;' in perm
assert 'else if(kind==1&&ADPermissionCameraCheckbox7408(v))' not in perm
# Exact permission button text descendants are white even after late React hydration.
for tok in ['ADPermissionButtonText7409','ADPermissionTextString7409','ADPermissionTextStorage7409']:
    assert tok in perm,tok
for aid in ['actionButton','inflight-prompt-dismiss-button','inflight-prompt-allow-button']:
    assert aid in perm
# Single border owner: rewrite React border, keep radius 8, no CALayer ring.
own=re.search(r'static void ADPermissionOwnView7408\(UIView \*v\)\{(.*?)\n\}',S,re.S).group(1)
assert 'setBorderColor:' in own and 'setBorderRadius:' in own and '8.0' in own
assert 'v.layer.borderWidth=0.0' in own and 'v.layer.borderColor=nil' in own
hooks=S[S.index('- (void)setBorderRadius:(CGFloat)value {'):S.index('// v7.285 Alexa/Rufus vector controls')]
assert '%orig(8.0);' in hooks
assert 'pv.layer.borderWidth=0.0; pv.layer.borderColor=nil;' in hooks
# Location rails: exact r4 local witness can own shell without waiting for root marker.
loc=S[S.index('static BOOL ADLocationInsetScrollerWitness7409'):S.index('// v7.401 FULL r5/r6:')]
for tok in ['RCTScrollView','0.89','0.94','xr.size.height>=330.0','v.clipsToBounds','v.subviews.count!=1']:
    assert tok in loc,tok
assert 'ADLocationRootAny7202(v)' in loc
assert 'ADLocationRootActive7202(v,&root)' not in loc
assert 'ADLocationTransitionTopRail7410' in loc
# No recurring machinery added.
for bad in ['new MutationObserver(','setInterval(','requestAnimationFrame(',"addEventListener('scroll'",'dispatch_after(']:
    assert bad not in perm+loc,bad
print('PASS: v7.409 preserves Camera checkbox, forces permission button text light, uses one rounded gray React border, and closes location side-rail timing hole')

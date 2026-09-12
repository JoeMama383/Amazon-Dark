from pathlib import Path
import json,re
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text(); C=(ROOT/'layout/DEBIAN/control').read_text()
UI=(ROOT/'scripts/ui-probe.sh').read_text(); SK=(ROOT/'scripts/skeleton-probe.sh').read_text(); INC=(ROOT/'src/ADUniversalUIProbe7362.inc').read_text()
F=json.loads((ROOT/'tests/fixtures/v7410-permission-location-transition.json').read_text())
assert 'Version: 7.413~address-location-compile-fix' in C
assert '#define AD_VERSION "v7.413-address-location-compile-fix"' in S
assert 'VER=7.413' in UI and 'AD_PROBE_VERSION=7.413' in SK and 'AD_PROBE_NAME=AmazonDark-v7.413' in SK
assert 'AMAZONDARK v7.413 UNIVERSAL' in INC and 'AmazonDark-v7.413-ui-viewport.arm' in INC
perm=S[S.index('// v7.408 FULL r1/r2: camera and microphone permission prompts'):S.index('// v7.408 r4: the location sheet interior')]
# Earliest unique markers must classify before the late action control.
assert '@"inflight-prompt-title"' in perm and '@"inflight-prompt-description"' in perm
assert 'int kind=camera?1:(micTitle?2:0);' in perm
seq=F['microphone_mount_sequence']; assert seq[0]['id']=='allowTitle' and seq[-1]['id']=='actionButton' and seq[0]['tick']<seq[-1]['tick']
cam=F['camera_mount_sequence']; assert cam[1]['id']=='inflight-prompt-title' and cam[2]['id']=='inflight-prompt-description'
assert cam[1]['tick']<cam[-1]['tick'] and cam[2]['tick']<cam[-1]['tick']
# All neutral permission grays normalize white; saturated semantic links remain authored.
assert 'ADPermissionNeutralText7410' in perm and '(hi-lo)<=0.18&&hi<0.92' in perm
assert 'ADPermissionTextStorage7409(v,ts)' in S
assert 'ADPermissionAttributedString7410' in perm and 'some React loads use ParagraphComponentView' in perm
paragraph=S[S.index('%hook RCTParagraphComponentView'):S.index('%hook RCTTextView')]
assert '- (void)layoutSubviews' in paragraph and 'ADPermissionOwnText7408(v)' in paragraph
# Transition ownership must not depend on final shell height matching the scroller.
loc=S[S.index('static BOOL ADLocationInsetScrollerWitness7409'):S.index('// v7.401 FULL r5/r6:')]
for tok in ['xr.size.height>=330.0','xr.size.height<=430.0','CGRectGetMinX(xr)>=14.0','ADLocationTransitionTopRail7410']:
    assert tok in loc,tok
assert 'fabs(xr.size.height-vr.size.height)<=8.0' not in loc
assert 'ADLocationInsetScrollerWitness7409(v)' in loc
outer=loc[loc.index('static BOOL ADLocationOuterWhiteShell7408'):loc.index('static BOOL ADLocationTransitionTopRail7410')]
assert outer.index('ADLocationInsetScrollerWitness7409(v)') < outer.index('UIView *root=ADLocationRootAny7202(v)')
rail=loc[loc.index('static BOOL ADLocationTransitionTopRail7410'):]
assert 'ADLocationRootAny7202(v)' not in rail
assert 'fabs(CGRectGetMaxY(vr)-CGRectGetMinY(sr))>4.0' in loc
lf=F['location_transition']; assert lf['outer_shell']['first_height']<300 and lf['inset_scroller']['height']>330 and lf['top_rail']['height']==18
# No recurring machinery.
for bad in ['new MutationObserver(','setInterval(','requestAnimationFrame(',"addEventListener('scroll'",'dispatch_after(']:
    assert bad not in perm+loc,bad
print('PASS: v7.410 closes permission-text marker timing and location presentation-shell/top-rail first-paint gaps')

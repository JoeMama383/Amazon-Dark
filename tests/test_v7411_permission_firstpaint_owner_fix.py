from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text(); C=(ROOT/'layout/DEBIAN/control').read_text()
UI=(ROOT/'scripts/ui-probe.sh').read_text(); SK=(ROOT/'scripts/skeleton-probe.sh').read_text()
INC=(ROOT/'src/ADUniversalUIProbe7362.inc').read_text(); JS=(ROOT/'src/ADUniversalUIProbe7362.js.inc').read_text()
F=json.loads((ROOT/'tests/fixtures/v7411-permission-location-firstpaint.json').read_text())
assert 'Version: 7.416~location-canonical-owner' in C
assert '#define AD_VERSION "v7.416-location-canonical-owner"' in S
assert 'VER=7.416' in UI and 'AD_PROBE_VERSION=7.416' in SK and 'AD_PROBE_NAME=AmazonDark-v7.416' in SK
assert 'AMAZONDARK v7.416 UNIVERSAL' in INC and 'AmazonDark-v7.416-ui-viewport.arm' in INC
assert "version:'7.416'" in JS
# The actual bad location chronology disproves the old v7.410 test assumption.
seq=F['location_bad_sequence']
assert seq[0]['role']=='top_rail' and seq[0]['location_child_available'] is False
assert seq[1]['role']=='outer_shell' and seq[1]['rct_scrollview_available'] is False
assert seq[0]['tick'] < seq[1]['tick'] < seq[2]['tick'] < seq[3]['tick'] < seq[4]['tick']
assert seq[1]['early_inset_content'][2]==394
loc=S[S.index('// v7.411 transition replay correction:'):S.index('// v7.401 FULL r5/r6:')]
# First visible 8-24pt neutral plates are owned without route/root/scroller prerequisites.
plate=loc[loc.index('static BOOL ADAppCXNeutralTransitionPlate7411'):loc.index('static BOOL ADLocationInsetContentWitness7411')]
for tok in ['r.size.height>=8.0','r.size.height<=24.0','r.size.width>=wb.size.width*0.98','CGRectGetMinY(r)>=wb.size.height*0.50']:
    assert tok in plate,tok
for forbidden in ['ADLocationRootAny7202','ADLocationInsetScrollerWitness7409','kADLocationRootFirstPaint7202']:
    assert forbidden not in plate,forbidden
# Growing shell can be identified by the early 394pt RCTScrollContentView child before RCTScrollView exists.
assert 'ADLocationInsetContentWitness7411' in loc
assert 'ADClassNameIs7183(x.superview,"RCTScrollContentView")' in loc
outer=loc[loc.index('static BOOL ADLocationOuterWhiteShell7408'):loc.index('static BOOL ADLocationTransitionTopRail7410')]
assert 'ADLocationInsetContentWitness7411(v)||ADLocationInsetScrollerWitness7409(v)' in outer
# Button labels are exact-owned by parent IDs before any sheet/window classification.
perm=S[S.index('static BOOL ADPermissionButtonText7409'):S.index('// v7.408 r4: the location sheet interior')]
for ident in ('actionButton','inflight-prompt-dismiss-button','inflight-prompt-allow-button'):
    assert ident in perm
storage=S[S.index('static BOOL ADThemeReactTextStorage7271'):S.index('static void ADOwnReactText7271')]
assert storage.index('ADPermissionButtonText7409(v)') < storage.index('if(!v.window)return NO;')
assert storage.index('ADPermissionButtonText7409(v)') < storage.index('ADPermissionSheetKind7408(v)')
draw=S[S.index('%hook RCTTextView'):S.index('%end',S.index('%hook RCTTextView'))]
assert draw.index('ADPermissionButtonText7409(v)') < draw.index('ADPermissionSheetKind7408(v)')
paragraph=S[S.index('%hook RCTParagraphComponentView'):S.index('%hook RCTTextView')]
assert 'ADPermissionButtonText7409(v)' in paragraph
# No new recurring runtime machinery.
new=loc+storage+paragraph
for bad in ['new MutationObserver(','setInterval(','requestAnimationFrame(',"addEventListener('scroll'",'dispatch_after(']:
    assert bad not in new,bad
print('PASS: v7.411 removes permission-button classification dependency and owns location transition plates before route/scroller hydration')

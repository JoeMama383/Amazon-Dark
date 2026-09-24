from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.480~camera-permission-build-repair' in C
assert '#define AD_VERSION "v7.480-camera-permission-build-repair"' in S
assert len(S.encode()) < 856000, len(S.encode())

# VIEWPORT 085327: exact TNF number spans already have the right selector.
# v7.480 adds an independent inset-black paint layer so a competing white
# background declaration cannot remain visible; labels are excluded by class.
sel='[id^=atf-countdownCard-Text-Timer-Numeric-][class*=_Timer-Numeric__]'
assert sel+'{background:#000!important;box-shadow:inset 0 0 0 64px #000!important}' in S
assert sel in S and 'color:#fff!important;-webkit-text-fill-color:#fff!important' in S
assert '_Timer-Numeric-Bottom__' not in S[S.index(sel+'{background'):S.index(sel+'{background')+250]

# FULL 075301: exact React owner has borderTopWidth=1.00. Reuse the proven
# single-border normalizer at width 0 for only AXFActionBarContainer.
assert 'if([v.accessibilityIdentifier isEqualToString:@"AXFActionBarContainer"])ADMenuSetSingleRCTBorder7258(v,0.0,nil);' in S
assert '[v.accessibilityIdentifier isEqualToString:@"AXFActionBarTextButton"]' in S
assert 'ADMenuSetSingleRCTBorder7258(v,1.0,ADMenuButtonBorder7255())' in S
helper=S[S.index('static void ADMenuSetSingleRCTBorder7258'):S.index('// v7.285 Alexa/Rufus',S.index('static void ADMenuSetSingleRCTBorder7258'))]
for t in ('setBorderTopWidth:', 'setBorderTopColor:', '-1.0', 'v.layer.borderWidth=0.0'):
    assert t in helper,t

# No recurring production scanner is introduced by this follow-up.
block=S[S.index('static NSString *ADPDPProbeBackedFixesJS7458'):S.index('static NSString *ADCoreWebJS7271')]
for bad in ('MutationObserver(', 'setInterval(', 'requestAnimationFrame('): assert bad not in block
for h in ('## FULL — v7.480','## VIEWPORT — v7.480','## TRANSITION — v7.480'): assert h in CMD
print('PASS: v7.480 covers the TNF visible white paint and clears only the PDP action-bar container top edge')

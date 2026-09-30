from pathlib import Path
import json
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text()
H=(R/'src/ADSkeletonProbe7339.h').read_text()
J=''.join(json.loads(line) for line in (R/'src/ADReturnsTheme7480.js.inc').read_text().splitlines() if line.strip())
C=(R/'layout/DEBIAN/control').read_text()
CMD=(R/'COMMANDS.md').read_text()
SK=(R/'scripts/skeleton-probe.sh').read_text()

assert 'Version: 7.489~active-returns-ami-lifecycle-probe' in C
assert '#define AD_VERSION "v7.489-active-returns-ami-lifecycle-probe"' in T
assert len(T.encode()) < 856000, len(T.encode())
for h in ('## FULL — v7.489','## VIEWPORT — v7.489','## TRANSITION — v7.489'):
    assert h in CMD, h
assert ' status' not in CMD.lower()

# FULL r1 exact owner: Active Returns sits under .active-returns-section.instrumentation,
# whose inherited neutral rgb(15,17,17) survived while the card descendants were white.
assert '#a-page:has(.your-returns-page-container.instrumentation) .active-returns-section{color:#fff!important;-webkit-text-fill-color:#fff!important;}' in J
assert '.active-returns-section :is(h1,h2,h3,h4,h5,h6,.a-size-base,.a-size-small,.a-size-medium,.a-size-large,.a-color-base,.a-color-secondary,.a-color-tertiary,.a-text-normal,.a-text-bold,p,span,div,strong,b)' in J
for preserve in (':not(a)', ':not(.a-color-link)', ':not(.a-color-price)', ':not(.a-color-success)', ':not(.a-color-error)', ':not(.a-color-state)'):
    assert preserve in J

# Expanded transition diagnostics: mark the exact AMI root at setView before responder
# attachment, then correlate incoming background writes, window attachment and VC lifecycle.
for tok in (
    'BOOK_AMI_VIEW', 'BOOK_AMI_CONTROLLER', 'kADSkelBookAMIRoot7489',
    'nextResponderClass', 'incomingColor', 'superClass', 'presentationBG',
    'parentController', 'presentingController', 'presentedController', 'coordinator',
):
    assert tok in H, tok
for tok in (
    'ADSkelBookAMIControllerEvent7489(self,@"setView.pre",view);',
    'ADSkelBookAMIControllerEvent7489(self,@"setView.post",view);',
    'ADSkelBookAMIControllerEvent7489(self,@"didLoad.pre",self.viewIfLoaded);',
    'ADSkelBookAMIControllerEvent7489(self,@"willAppear.pre",self.viewIfLoaded);',
    'ADSkelBookAMIControllerEvent7489(self,@"willDisappear.pre",self.viewIfLoaded);',
    'ADSkelBookAMIControllerEvent7489(self,@"layout.post",self.viewIfLoaded);',
    'ADSkelBookAMIViewEvent7489(self,@"bg.in",color,nil);',
    'ADSkelBookAMIViewEvent7489(self,@"move.pre",nil,nil);',
    'ADSkelBookAMIViewEvent7489(self,@"move.post",nil,nil);',
):
    assert tok in T, tok

# Probe remains read-only. Associated-object marking is diagnostic identity only.
for bad in ('ADSetViewBackground7226', 'setBackgroundColor:', 'setAlpha:', 'setHidden:', 'removeFromSuperview', 'addSubview:'):
    assert bad not in H[H.index('// v7.489 transition expansion:'):H.index('static void ADSkelSplash7339')], bad
assert 'reproduce the complete transition in both directions (present and dismiss)' in SK

print('PASS: v7.489 whitens the exact Active Returns section and expands read-only AMI lifecycle/root diagnostics')

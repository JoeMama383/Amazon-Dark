from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text()
# v7.440 remains in source history, but its runtime frame traversal is retired in v7.442.
for tok in ['ADForcedPDPFrameThemeJS7440','ADInjectFrameNode7440','ADForceChildFrameTheme7440','ADFrameOwnerAttach7440']:
    assert tok in S,tok
core=S[S.index('static NSString *ADCoreWebJS7271'):S.index('// v7.442: Replace')]
assert 'ADFrameOwnerTriggerJS7440()' not in core
start=S.index('static void ADAttachScriptsToUCC710'); attach=S[start:start+5000]
assert 'ADFrameOwnerAttach7440(ucc)' not in attach
assert 'ADUserStyleAttach7442(ucc)' in attach
assert 'ADForceChildFrameTheme7440(self)' not in S
print('PASS: v7.440 frame-walker implementation is retained only as history and is inactive in v7.442')

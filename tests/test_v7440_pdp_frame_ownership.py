from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text()
# v7.443 fully removes the retired v7.440 frame traversal/message bridge instead of
# leaving dead static code in the production translation unit.
for tok in ['ADForcedPDPFrameThemeJS7440','ADFrameOwnerTriggerJS7440','ADPageWorld7440','ADInjectFrameNode7440','ADForceChildFrameTheme7440','ADFrameOwnerBridge7440','ADFrameOwnerAttach7440']:
    assert tok not in S,tok
assert 'ADPDPMainResidualJS7440' in S
start=S.index('static void ADAttachScriptsToUCC710'); attach=S[start:start+5000]
assert 'ADUserStyleAttach7442(ucc)' in attach
print('PASS: v7.443 removes the retired v7.440 frame walker/bridge while retaining the exact main-document residual')

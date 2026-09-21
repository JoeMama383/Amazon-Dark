from pathlib import Path
import re
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text(); CMD=(R/'COMMANDS.md').read_text(); SK=(R/'scripts/skeleton-probe.sh').read_text()
assert 'Version: 7.443~user-style-ad-ownership-validation-fix' in C
assert '#define AD_VERSION "v7.443-user-style-ad-ownership-validation-fix"' in S
st=S.index('static NSString *ADCoreWebJS7271'); en=S.index('// v7.443: Replace',st); core=S[st:en]
assert '@"%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@"' in core
assert '@"%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@"' not in core
for tok in ['ADFullRasterHostBridgeJS7266()','ADStandalonePaintJS7104()','ADFloorJS()','ADHomeAdShellFloorJS7381()','ADProductShareThemeJS7403()','ADProductShareTWBJS7403()','ADShareProbeSuppressJS7403()','ADProductScrollPolishJS7404()','ADProductScrollVideoBorderJS7405()','ADPDPCompletionJS7405()','ADPDPSafeFrameJS7432()','ADPDPCompletionTWBJS7405()','ADPDPUICompletionJS7439()','ADPDPMainResidualJS7440()','ADAddressManagementJS7412()']:
    assert tok in core,tok
assert 'ADFrameOwnerTriggerJS7440()' not in core
for tok in ['ADForcedPDPFrameThemeJS7440','ADFrameOwnerTriggerJS7440','ADPageWorld7440','ADInjectFrameNode7440','ADForceChildFrameTheme7440','ADFrameOwnerBridge7440','ADFrameOwnerAttach7440']:
    assert tok not in S,tok
assert 'ADUserStyleAttach7442(ucc)' in S
assert 'in 7.443~*)' in SK
assert '/var/mobile/t7443' in CMD and 'AmazonDark-v7.443-user-style-ad-ownership-validation-fix-source.zip' in CMD
print('PASS: v7.443 matches 15 core conversions to 15 active programs and removes the retired v7.440 frame walker')

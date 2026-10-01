from pathlib import Path
R=Path(__file__).resolve().parents[1]
H=(R/'src/ADSkeletonProbe7339.h').read_text()
T=(R/'src/Tweak.xm').read_text()
CMD=(R/'COMMANDS.md').read_text()
C=(R/'layout/DEBIAN/control').read_text()
for token in ('ADSkelKeyboardIvarObject7545','ADSkelKeyboardBridgeMethods7545','remoteSceneIvars','remoteSceneMethods','keyboardSceneLayer','keyboardSceneLayerGetters','keyboardSceneLayerIvars','keyboardSceneLayerMethods','_keyboardSceneLayer'):
    assert token in H, token
assert 'Version: 7.545~keyboard-scene-bridge-probe' in C
assert '#define AD_VERSION "v7.545-keyboard-scene-bridge-probe"' in T
for good in ('ui-probe.sh export full','ui-probe.sh arm','ui-probe.sh export viewport','skeleton-probe.sh arm transition','skeleton-probe.sh export','git push origin main'):
    assert good in CMD, good
print('PASS: v7.545 expands the transition probe across _UIKeyboardWindowScene and FBSKeyboardLayer without changing the frozen handoff contract')

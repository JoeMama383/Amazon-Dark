from pathlib import Path
R=Path(__file__).resolve().parents[1]
H=(R/'src/ADSkeletonProbe7339.h').read_text()
T=(R/'src/Tweak.xm').read_text()
C=(R/'layout/DEBIAN/control').read_text()
CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.619~handoff-regression-repair' in C
assert '#define AD_VERSION "v7.619-handoff-regression-repair"' in T
assert 'AmazonDark-v7.619-handoff-regression-repair-source*.zip' in CMD
for token in ('KEYBOARD_PRIVATE_STATE','ADSkelKeyboardIvars7544','ADSkelKeyboardGetterState7544','ADSkelKeyboardMethodSignatures7544','ADSkelKeyboardClassInventory7544'):
    assert token in H, token
for token in ('responderStylingTraits','stylingTraits','responderStylingTraitsForceEditingMask:','updateStylingTraitsIfNeeded','updateInputDelegateForRemoteTraitChange:forceSync:'):
    assert token in H, token
for token in ('remoteWindow','remoteScene','remoteSceneDelegate','effectsController','classInventory'):
    assert token in H, token
assert '@50,@200,@600,@1200,@2000,@3000,@4500,@6500' in H
# Diagnostic-only: the production keyboard policy remains exactly the inherited v7.543 path.
legacy=T.split('%hook UITextInputTraits',1)[1].split('%end',1)[0]
assert 'UIKeyboardAppearance a=%orig;' in legacy
assert 'UIKeyboardAppearance next=gP.enabled?UIKeyboardAppearanceDark:a;' in legacy
fx=T.split('%hook UITextEffectsWindow',1)[1].split('%end',1)[0]
assert '%orig(UIUserInterfaceStyleDark);' in fx
assert 'self.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;' in fx
# The new private-state block itself is read-only; it must not write appearance, responder, geometry, or keyboard traits.
probe=H.split('static NSArray *ADSkelKeyboardIvars7544',1)[1].split('static NSString *ADSkelName7339',1)[0]
for bad in ('setKeyboardAppearance:', 'setOverrideUserInterfaceStyle:', 'becomeFirstResponder', 'setBackgroundColor:', 'setFrame:', 'setBounds:'):
    assert bad not in probe, bad
for good in ('ui-probe.sh export full','ui-probe.sh arm','ui-probe.sh export viewport','skeleton-probe.sh arm transition','skeleton-probe.sh export','git push origin main'):
    assert good in CMD,good
for bad in ('git init','git push -uf','rm -rf .git'):
    assert bad not in CMD,bad
print('PASS: v7.619 expands the opt-in transition probe into responder styling, UIKeyboardImpl private state, and the remote keyboard window/scene boundary without changing production behavior')

from pathlib import Path
R=Path(__file__).resolve().parents[1]
H=(R/'src/ADSkeletonProbe7339.h').read_text()
T=(R/'src/Tweak.xm').read_text()
C=(R/'layout/DEBIAN/control').read_text()
CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.619~handoff-regression-repair' in C
assert '#define AD_VERSION "v7.619-handoff-regression-repair"' in T
assert 'AmazonDark-v7.619-handoff-regression-repair-source*.zip' in CMD
assert 'KEYBOARD_CONSUMER' in H
assert 'UIKeyboardImpl' in H
assert 'implMethodHints' in H
assert 'keyboardAppearance' in H and 'overrideStyle' in H and 'traitStyle' in H
assert 'firstResponder' in H and 'UIInputSetHostView' in H and '_UIRemoteKeyboardPlaceholderView' in H
assert '@50,@200,@600,@1200,@2000' in H
assert 'UIKeyboardDidShowNotification' in H and 'ADSkelKeyboardConsumerBurst7542' in H
probe=H.split('// v7.619 keyboard consumer trace.',1)[1].split('static NSString *ADSkelName7339',1)[0]
for bad in ('setKeyboardAppearance:', 'setOverrideUserInterfaceStyle:', 'becomeFirstResponder', 'setBackgroundColor:', 'setFrame:'):
    assert bad not in probe, bad
# Production keyboard policy remains the v7.541 behavior; this release only expands opt-in evidence.
legacy=T.split('%hook UITextInputTraits',1)[1].split('%end',1)[0]
assert 'UIKeyboardAppearance a=%orig;' in legacy
assert 'UIKeyboardAppearance next=gP.enabled?UIKeyboardAppearanceDark:a;' in legacy
for good in ('ui-probe.sh export full','ui-probe.sh arm','ui-probe.sh export viewport','skeleton-probe.sh arm transition','skeleton-probe.sh export','git push origin main'):
    assert good in CMD, good
for bad in ('git init','git push -uf','rm -rf .git'):
    assert bad not in CMD,bad
print('PASS: v7.619 expands transition evidence to the UIKit keyboard consumer boundary without changing production keyboard or modal behavior')

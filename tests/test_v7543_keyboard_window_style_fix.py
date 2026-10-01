from pathlib import Path
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text(); H=(R/'src/ADSkeletonProbe7339.h').read_text(); C=(R/'layout/DEBIAN/control').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.543~keyboard-window-style-fix' in C
assert '#define AD_VERSION "v7.543-keyboard-window-style-fix"' in T
assert '@interface UITextEffectsWindow : UIWindow @end' in T
block=T.split('%hook UITextEffectsWindow',1)[1].split('%end',1)[0]
assert '- (void)setOverrideUserInterfaceStyle:(UIUserInterfaceStyle)style {' in block
assert '%orig(UIUserInterfaceStyleDark);' in block
assert 'self.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;' in block
for bad in ('setFrame:', 'setBounds:', 'setTransform:', 'setCenter:', 'setBackgroundColor:'):
    assert bad not in block,bad
# Keep the evidence that identified this owner so the next transition can verify it stays Dark.
assert 'UITextEffectsWindow' in H and 'overrideStyle' in H and 'traitStyle' in H and 'KEYBOARD_CONSUMER' in H
# Existing traits clamp and frozen probe handoff remain intact.
legacy=T.split('%hook UITextInputTraits',1)[1].split('%end',1)[0]
assert 'UIKeyboardAppearance next=gP.enabled?UIKeyboardAppearanceDark:a;' in legacy
for good in ('ui-probe.sh export full','ui-probe.sh arm','ui-probe.sh export viewport','skeleton-probe.sh arm transition','skeleton-probe.sh export','git push origin main'):
    assert good in CMD,good
for bad in ('git init','git push -uf','rm -rf .git'):
    assert bad not in CMD,bad
print('PASS: v7.543 clamps only the probe-proven Light UITextEffectsWindow while preserving the existing dark keyboard traits and modal geometry contract')

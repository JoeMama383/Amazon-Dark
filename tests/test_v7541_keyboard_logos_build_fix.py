from pathlib import Path
import re, subprocess, tempfile
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.541~keyboard-legacy-build-fix' in C
assert '#define AD_VERSION "v7.541-keyboard-legacy-build-fix"' in S
block=S.split('%hook UITextInputTraits',1)[1].split('%end',1)[0]
# Logos bare %orig replaces through end-of-line. Never place another declaration after it.
assert 'UIKeyboardAppearance a=%orig;\n    UIKeyboardAppearance next=gP.enabled?UIKeyboardAppearanceDark:a;' in block
assert not re.search(r'%orig\s*,', block)
assert 'ADKeyboardTrace7538(self,@"legacy.read",a,next);' in block and 'return next;' in block
assert 'UIKeyboardAppearance next=gP.enabled?UIKeyboardAppearanceDark:a;' in block
assert '%orig(next);' in block and 'ADKeyboardTrace7538(self,@"legacy.write",a,next);' in block
# Keep the established handoff unchanged except release identity.
for good in ('ui-probe.sh export full','ui-probe.sh arm','ui-probe.sh export viewport','skeleton-probe.sh arm transition','skeleton-probe.sh export','git push origin main'):
    assert good in CMD,good
for bad in ('git init','git push -uf','rm -rf .git'):
    assert bad not in CMD,bad
# The project linter must now reject the exact v7.540 Logos footgun too.
with tempfile.TemporaryDirectory() as d:
    f=Path(d)/'bad.xm'; f.write_text('id x=%orig,next=1;\n')
    r=subprocess.run(['bash',str(R/'scripts/lint-logos.sh'),str(f)],text=True,capture_output=True)
    assert r.returncode!=0 and 'bare %orig is followed by a comma' in (r.stdout+r.stderr)
print('PASS: v7.541 keeps the legacy keyboard clamp but makes the getter Logos-safe by terminating bare %orig before the next declaration')

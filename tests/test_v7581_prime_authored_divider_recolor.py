from pathlib import Path
import json, subprocess, tempfile
R=Path(__file__).resolve().parents[1]
M=(R/'src/ADNewMenus7482.js.inc').read_text()
C=(R/'layout/DEBIAN/control').read_text()
T=(R/'src/Tweak.xm').read_text()
CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.581~prime-authored-divider-recolor' in C
assert '#define AD_VERSION "v7.581-prime-authored-divider-recolor"' in T
assert 'AmazonDark-v7.581-prime-authored-divider-recolor-source.zip' in CMD
start=M.index('/* v7.575 VIEWPORT: exact Prime Deals follow-up.')
end=M.index('/* v7.580 VIEWPORT: Prime Deals refinement sheets are paint-only', start)
frag=M[start:end]
# Never synthesize horizontal separators on the two child bars again.
assert '[class*=PrioritizedInformationBar-module__container_],[class*=RefinementBar-module__refinementBarContainer_]' not in frag
for forbidden in ('border-top:1px','border-bottom:1px','border:1px solid #494d4d'):
    assert forbidden not in frag, forbidden
# Recolor only Amazon's authored parent top/bottom border sides; do not set widths/styles.
needle='body:has(.discounts-react-app) [class*=MobileDiscountAsinGrid-module__informationBarAndRefinementButtonContainer_]{border-top-color:#494d4d!important;border-bottom-color:#494d4d!important;}'
assert needle in frag
# Existing thin vertical divider nodes are paint-only too.
assert 'body:has(.discounts-react-app) :is([class*=RefinementBar-module__dividerBar_],[class*=AlexaBubble-module__alexaDivider_]){background:#494d4d!important;}' in M
# The old broad descendant divider recolor was removed; it could reveal dormant borders.
assert ':is([class*=PrioritizedInformationBar-module__container_],[class*=RefinementBar-module__refinementBarContainer_]) :is(hr,.a-divider' not in M
parts=[json.loads(line.strip()) for line in M.splitlines() if line.strip()]
with tempfile.NamedTemporaryFile(suffix='.js',mode='w') as f:
    f.write(''.join(parts)); f.flush(); subprocess.run(['node','--check',f.name],check=True,capture_output=True)
print('PASS: v7.581 removes synthetic Prime tab/refinement separators and recolors only Amazon-authored divider geometry')

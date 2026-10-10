from pathlib import Path
import json, subprocess, tempfile
R=Path(__file__).resolve().parents[1]
M=(R/'src/ADNewMenus7482.js.inc').read_text()
C=(R/'layout/DEBIAN/control').read_text()
T=(R/'src/Tweak.xm').read_text()
CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.619~handoff-regression-repair' in C
assert '#define AD_VERSION "v7.619-handoff-regression-repair"' in T
assert 'AmazonDark-v7.619-handoff-regression-repair-source.zip' in CMD
# The old global Prime button rule must never match a-sheet or dialog buttons again.
old_rule=M[M.index('body:has(.discounts-react-app) :is([class*=RefinementPill-module__refinementPill_]'):M.index('\n"',M.index('body:has(.discounts-react-app) :is([class*=RefinementPill-module__refinementPill_]'))]
assert '.a-sheet-web .a-button' not in old_rule
assert '[role=dialog] button' not in old_rule
# Legacy AUI sheet rules are disabled whenever the temporary React bottom sheet exists.
for token in (
    'body:has(.discounts-react-app):not(:has(.discounts-react-app-bottom-sheet)) :is(.a-popover-wrapper',
    'body:has(.discounts-react-app):not(:has(.discounts-react-app-bottom-sheet)) :is(.a-popover,.a-sheet-web,[role=dialog]) :is(.a-box'
):
    assert token in M, token
start=M.index('/* v7.580 VIEWPORT: Prime Deals refinement sheets are paint-only and border-promotion-free.')
end=M.index('/* v7.570: captured grocery paint owners',start)
frag=M[start:end]
# No gray-border paint may target header/section wrappers, range container, close button, or See more.
assert ':is([class*=BottomSheetRefinements-module__headerWithShadow_],[class*=BottomSheet-module__footer_],[class*=Section-module__section_]' not in frag
assert '[class*=RangeSelectInputMobile-module__container_]{background:#000!important;background-color:#000!important;border-color:' not in frag
assert '[class*=Section-module__seeMore_]{' in frag and 'border-color:transparent!important' in frag
assert '[class*=Header-module__headerButton_]' in frag and 'outline:none!important' in frag
# Gray border-color remains only on actual divider families and authored pills/footer buttons.
assert ':is(hr,.a-divider,.a-divider-inner,.a-divider-normal,[class*=divider],[class*=Divider],[class*=separator],[class*=Separator]){background-color:#494d4d!important;border-color:#494d4d!important' in frag
assert '[class*=Pill-module__pill_]{' in frag and 'border-color:#747a7c!important' in frag
assert '[class*=Footer-module__clearFilters_],[class*=Footer-module__showResults_]) .a-button' in frag
parts=[json.loads(line.strip()) for line in M.splitlines() if line.strip()]
with tempfile.NamedTemporaryFile(suffix='.js',mode='w') as f:
    f.write(''.join(parts)); f.flush(); subprocess.run(['node','--check',f.name],check=True,capture_output=True)
print('PASS: v7.580 removes close/header/See-more border promotion while preserving only authored control/divider paint')

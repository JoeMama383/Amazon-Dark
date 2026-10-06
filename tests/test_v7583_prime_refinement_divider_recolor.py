from pathlib import Path
R=Path(__file__).resolve().parents[1]
M=(R/'src/ADNewMenus7482.js.inc').read_text()
T=(R/'src/Tweak.xm').read_text()
C=(R/'layout/DEBIAN/control').read_text()
assert 'Version: 7.583~prime-refinement-divider-recolor' in C
assert '#define AD_VERSION "v7.583-prime-refinement-divider-recolor"' in T
marker='/* v7.583 VIEWPORT: recolor only probe-proven authored 1px Prime refinement dividers; never create widths/sides. */'
assert marker in M
frag=M.split(marker,1)[1].split('/* v7.570: captured grocery paint owners',1)[0]
for token in (
    '[class*=BottomSheetRefinements-module__headerWithShadow_]{border-bottom-color:#494d4d!important;}',
    '[class*=Section-module__section_]{border-bottom-color:#494d4d!important;}',
    '[class*=BottomSheet-module__footer_]{border-top-color:#494d4d!important;}',
): assert token in frag, token
for forbidden in ('border-bottom:1px','border-top:1px','border-width:','border:1px','border:2px','border-radius:','outline:1px','outline:2px'):
    assert forbidden not in frag, forbidden
print('PASS: v7.583 recolors only the three probe-proven authored Prime refinement divider sides without creating geometry')

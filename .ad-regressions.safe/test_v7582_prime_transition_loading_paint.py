from pathlib import Path
import json, subprocess, tempfile
R=Path(__file__).resolve().parents[1]
M=(R/'src/ADNewMenus7482.js.inc').read_text()
T=(R/'src/Tweak.xm').read_text()
C=(R/'layout/DEBIAN/control').read_text()
CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.619~handoff-regression-repair' in C
assert '#define AD_VERSION "v7.619-handoff-regression-repair"' in T
assert 'AmazonDark-v7.619-handoff-regression-repair-source.zip' in CMD
for tok in (
 '/* v7.619 TRANSITION: probe-confirmed Prime Deals loading owners. Paint only: no new geometry. */',
 '.dps-slot-adapter.dps-slot-adapter-themed{background:#000!important;background-color:#000!important;}',
 '[class*=SkeletonBox-module__image_],[class*=SkeletonBox-module__textLine_]{background:#303335!important;background-color:#303335!important;box-shadow:none!important;}',
 '#ape_Events_320x50-mobile-atf_mshop_placement,#ape_Events_320x50-mobile-atf_mshop_iframe,html:has(#adLink) :is(#ad,#absoluteComponents,#adLink),html:has(#adLink) :is(#ad,#absoluteComponents,#adLink)::before,html:has(#adLink) :is(#ad,#absoluteComponents,#adLink)::after{border-color:#494d4d!important;outline-color:#494d4d!important;box-shadow:none!important;}'
): assert tok in M,tok
# This transition patch may recolor an existing border but must never synthesize geometry.
frag=M.split('/* v7.619 TRANSITION:',1)[1].split('/* v7.570 Prime Deals',1)[0]
for bad in ('border:1px','border:2px','border-width:','border-top-width:','border-bottom-width:','outline:1px','outline:2px','box-shadow:inset'):
 assert bad not in frag,bad
# The ADNewMenus JS include must still reconstruct to valid JavaScript.
J=''.join(json.loads(l) for l in M.splitlines() if l.strip())
with tempfile.NamedTemporaryFile(mode='w',suffix='.js') as f:
 f.write(J);f.flush();subprocess.run(['node','--check',f.name],check=True,capture_output=True)
print('PASS: v7.619 owns the captured Prime loading plate and SkeletonBox paint at document start and recolors the compact 320x50 ad border without creating new geometry')

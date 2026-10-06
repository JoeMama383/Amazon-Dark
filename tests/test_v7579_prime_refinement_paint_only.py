from pathlib import Path
import json, subprocess, tempfile
R=Path(__file__).resolve().parents[1]
M=(R/'src/ADNewMenus7482.js.inc').read_text()
C=(R/'layout/DEBIAN/control').read_text()
T=(R/'src/Tweak.xm').read_text()
CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.580~prime-refinement-border-cleanup' in C
assert '#define AD_VERSION "v7.580-prime-refinement-border-cleanup"' in T
assert 'AmazonDark-v7.580-prime-refinement-border-cleanup-source.zip' in CMD
start=M.index('/* v7.580 VIEWPORT: Prime Deals refinement sheets are paint-only and border-promotion-free.')
end=M.index('/* v7.570: captured grocery paint owners',start)
frag=M[start:end]
for forbidden in ('border:1px','border:2px','border-top:','border-bottom:','border-left:','border-right:','border-radius:','outline-color:','display:inline-flex','box-sizing:','width:','height:'):
    assert forbidden not in frag, forbidden
for required in (
    'background:#000!important;background-color:#000!important',
    '[class*=Footer-module__clearFilters_],[class*=Footer-module__showResults_]) .a-button',
    '[class*=RangeSlider-module__innerRail_]{background:#2162a1!important;background-color:#2162a1!important;}',
    '[class*=Section-module__title_]){color:#fff!important;-webkit-text-fill-color:#fff!important;}',
    '[class*=Section-module__seeMore_]{background:transparent!important',
    '[class*=Header-module__headerButton_]',
    'border-color:transparent!important;outline:none!important;box-shadow:none!important'
):
    assert required in frag, required
assert '[class*=RangeSlider-module__control_]' not in frag
assert '[class*=RangeSlider-module__thumb_]' not in frag
parts=[]
for line in M.splitlines():
    line=line.strip()
    if line:
        parts.append(json.loads(line))
js=''.join(parts)
with tempfile.NamedTemporaryFile(suffix='.js',mode='w') as f:
    f.write(js); f.flush(); subprocess.run(['node','--check',f.name],check=True,capture_output=True)
print('PASS: current Prime refinement sheets remain geometry-safe and explicitly suppress close/See-more border promotion')

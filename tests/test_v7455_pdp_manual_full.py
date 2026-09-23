from pathlib import Path
import json, subprocess, tempfile
R=Path(__file__).resolve().parents[1]
I=(R/'src/ADUniversalUIProbe7362.inc').read_text()
TRACK=(R/'src/ADPDPManualTracker7455.js.inc').read_text()
SAMPLE=(R/'src/ADPDPManualSample7455.js.inc').read_text()

def decode_c_strings(text):
    return ''.join(json.loads(line) for line in text.splitlines() if line.strip())

track=decode_c_strings(TRACK)
sample=decode_c_strings(SAMPLE)

# The tracker observes user scroll only. There must be no scroll mutation API in
# either PDP-only JavaScript payload.
for tok in ["addEventListener('scroll',onScroll,true)", "removeEventListener('scroll',onScroll,true)",
            "phase:'pdp-manual-scroll-signal'", "setTimeout(function(){emit('scroll-idle');},220)"]:
    assert tok in track, tok
for js in (track,sample):
    for bad in ['scrollTo(', '.scrollTop=', '.scrollLeft=', 'requestAnimationFrame(', 'MutationObserver(', 'setInterval(']:
        assert bad not in js, bad

# Manual samples are bounded to the visible scene rather than serializing the
# entire 10k+ node Product Detail DOM on each checkpoint.
for tok in ['elementsFromPoint','nodes.length>=cap','cap=460','visible-semantic','programmaticScrollWrites:0']:
    assert tok in sample, tok
assert 'createTreeWalker' not in sample
assert 'getElementsByTagName(\'*\').length' in track  # metric only, not traversal/styling

# Native integration starts one temporary tracker, samples on idle checkpoints,
# and stops it at bottom/background/timeout without calling the generic walker.
manual=I[I.index('static NSString *ADPDPManualTrackerJS7455'):I.index('static void ADUIScanNativeAxis7364')]
for tok in ['ADPDPManualTrackerJS7455','ADPDPManualSampleJS7455','ADUIPDPManualRunCheckpoint7455',
            'PDP_MANUAL_BACKGROUND_STOP','PDP_MANUAL_TIMEOUT after=300s','__adPDPManualStop7455']:
    assert tok in manual, tok
router=I[I.index('static void ADUIProcessWebViews7364'):I.index('static void ADUIScanNativeAxis7364')]
pdp_branch=router[router.index('if(gADUIFullHasPDP7451)'):router.index('ADUIScanWebViewFull7364')]
assert 'ADUIScanPDPManual7455' in pdp_branch
assert 'ADUIScrollCommand7446' not in pdp_branch

# Compile C-string includes and syntax-check emitted JS exactly as shipped.
for name,src,expected in [('tracker','ADPDPManualTracker7455.js.inc',track),('sample','ADPDPManualSample7455.js.inc',sample)]:
    with tempfile.TemporaryDirectory(prefix='ad7455-') as td:
        td=Path(td); cpp=td/'x.cpp'; exe=td/'x'
        cpp.write_text('#include <cstdio>\nstatic const char s[]=\n#include "'+src+'"\n;\nint main(){return std::fwrite(s,1,sizeof(s)-1,stdout)==sizeof(s)-1?0:1;}\n')
        subprocess.run(['c++','-std=gnu++98','-Wall','-Wextra','-Werror','-I',str(R/'src'),str(cpp),'-o',str(exe)],check=True)
        emitted=subprocess.check_output([str(exe)]).decode()
        assert emitted==expected
        subprocess.run(['node','--check'],input=emitted,text=True,check=True)

print('PASS: v7.455 PDP FULL is manual-scroll, bounded, read-only, and syntactically valid')

#!/usr/bin/env python3
"""Regression gate for the v5.451 experimental performance build.

This gate is intentionally additive: the v5.428 checkbox/Cart fixture and the
v5.450 Compare/Home fixture still run first in CI.  These checks lock the new
cross-window acquisition, early authored-paint ownership, and bounded scheduling
without relaxing any previously confirmed UI contract.
"""
from pathlib import Path
import sys


SRC = Path(sys.argv[1] if len(sys.argv) > 1 else "src/Tweak.xm")
src = SRC.read_text()
control = Path("layout/DEBIAN/control").read_text()
workflow = Path(".github/workflows/build.yml").read_text()
failures = []


def check(ok, label):
    print(("PASS" if ok else "FAIL") + ": " + label)
    if not ok:
        failures.append(label)


def between(start, end, label):
    a = src.find(start)
    b = src.find(end, a + len(start)) if a >= 0 else -1
    check(a >= 0 and b > a, f"{label} block present")
    return src[a:b] if a >= 0 and b > a else ""


check('#define AD_VERSION "v5.451.0"' in src and "Version: 5.451.0" in control,
      "runtime and package versions are v5.451.0")
check("AmazonDark-v5.451-experimental-performance-compare-home-rootless-deb" in workflow,
      "artifact is explicitly marked experimental performance")
for fixture in ("test-compare-native-428.py", "test-theme-surfaces-450.py",
                "test-performance-surfaces-451.py"):
    check(f"python3 scripts/{fixture} src/Tweak.xm" in workflow,
          f"CI retains {fixture}")


compare = between("// ── v5.451 CROSS-WINDOW COMPARE CONTROL",
                  "// ── P19 VOICE-PERMISSION", "cross-window Compare")
for token in (
    "UIScreen.mainScreen.coordinateSpace",
    "convertRect:inWindow toCoordinateSpace:screenSpace",
    "NSMutableArray *glyphs", "NSMutableArray *thumbs",
    "dx < -24 || dx > 64 || dy > 52",
    "ADImageIsDarkGlyph(bestGlyph.image",
    "clear451>.25 && avg451<.18 && sat451<.10",
    "kADCompareCircle451Key", "kADCompareMinus451Key",
    "circle.backgroundColor=[UIColor whiteColor].CGColor",
    "minus.backgroundColor=ADColorFromHex(gP.bgHex).CGColor",
    "circle.zPosition=10000", "minus.zPosition=10001",
    "const double delay451[]={0.01,0.18}",
    "for (int i451=0;i451<2;i451++)",
    "ADMovingScrollForCell451(v)",
    "P95COMPARE451[nodes=",
):
    check(token in compare, f"Compare contract {token[:70]}")
for forbidden in (
    "host.backgroundColor=", "host.layer.backgroundColor=",
    "host.frame=", "host.bounds=", "host.userInteractionEnabled",
    "[host setFrame:", "[host setBounds:", "[bestGlyph setImage:",
    ".click(", "dispatchEvent", "createElement('svg')",
):
    check(forbidden not in compare, f"Compare leaves stock geometry/action/image untouched: {forbidden}")
check("ADCompareCollect451(w,0,&nodes,t0+0.0028" in compare and "*nodes>=700" in compare,
      "Compare acquisition has one 2.8ms / 700-node ceiling")
check("gADCompare450Pending = YES;" in src and
      "if (!gADCompare450Pending) ADFixNativeCompare450();" in src,
      "failed six-pass v5.450 acquisition remains source-auditable but runtime-retired")


home_early = between("// v5.451 HOME AUTHOR-PAINT CAPTURE.",
                     '"try{if(document&&!document.getElementById(\'adcardfix\')){',
                     "early Home authored-paint")
check(src.find("// v5.451 HOME AUTHOR-PAINT CAPTURE.") < src.find("__acs.id='adcardfix'"),
      "Home ownership is installed before tweak/Dark Reader painters")
for token in (
    "window.__AD_HOMECAP451__", "theming-card-background",
    "single-video-card|video-card|video-js|vjs-|sbv-video",
    "e.__adHomeAuth451", "backgroundPriority", "colorPriority",
    "imagePriority", "filterPriority", "blendPriority", "shadowPriority",
    "data-ad-homecolor451", "{childList:true,subtree:true}",
    "window.__AD_THEME450_OBS__=1",
):
    check(token in home_early, f"Home early-owner contract {token[:70]}")
check("attributes:true" not in home_early and "characterData:true" not in home_early,
      "Home capture observes structure only and cannot observe its own paint writes")
for token in (
    ":not([data-ad-homecreative448]):not([data-ad-homecolor451])",
    "__AD_HOMEBG451_WRAP__", "return true;",
    "put451('background-color'", "put451('background-image'",
    "put451('filter'", "put451('background-blend-mode'", "put451('box-shadow'",
    "window.__AD_HOMECOLOR451__", "new MutationObserver(q451)",
    "window.__AD_THEME451_S__=setTimeout", "},320)",
):
    check(token in src, f"Home authored-color convergence contract {token[:70]}")
check("window.__AD_HOMEMEDIA395__" in src and "_adHomeMedia395" in src,
      "existing Home image WBT lane remains installed")


core = between("var __T0=Date.now(),__t0=__T0", "// Clear stray dark square wrappers",
               "budgeted JavaScript core")
for token in (
    "out.length<6000", "function ovr(){if(Date.now()-__t0>6)",
    "__ck('AQ2')", "((aq2&7)||!ovr())",
    "__AD_CORE_CURSOR451__", "(__coreStep&7)||!ovr()",
):
    check(token in core, f"JavaScript budget contract {token}")
check(src.find("var __T0=Date.now(),__t0=__T0") < src.find("var AQ=document.querySelectorAll"),
      "JavaScript deadlines initialize before both collectors")

checkbox = between("function stockCheckbox434()", "// v5.347 PDP HEART",
                   "stock checkbox runtime")
check("queue434(320)" in checkbox and "requestAnimationFrame" not in checkbox,
      "checkbox rescans once after scroll instead of every frame")
check("attributeFilter:['class','aria-checked','aria-pressed','aria-selected','data-checked','data-selected','data-state','checked','src','data-src']" in checkbox,
      "checkbox observer watches stock state/structure, not style")
check("__AD_RUNTIME451_DONE__" in src and "ADRuntimeWebJS451()" in src,
      "late painter installs once per document through lightweight runtime extraction")
focused = between("static NSString *ADRuntimeWebJS451(void)",
                  "// ── NATIVE HAIRLINE / BORDER SWEEP", "automatic web runtime")
check("[web evaluateJavaScript:ADRuntimeWebJS451()" in focused and
      "[web evaluateJavaScript:ADProbeWebJS()" not in focused,
      "automatic appearance path never evaluates the diagnostic payload")
for retired in ("__ad377rf", "__ad378tm", "_mb371raf"):
    check(retired not in src, f"per-frame/poll hot loop retired: {retired}")
check("queueRuntime451(320)" in src and src.count("new MutationObserver(function(){queueRuntime451(180);") == 1,
      "late runtime has one coalesced observer and one trailing scroll queue")
check("new MutationObserver(function(){q427(180);})" in src and
      "addEventListener('scroll',function(){q427(300);}" in src and
      "attributeFilter:['class']" in src,
      "frozen Heart owner is triggered by a state-only trailing finalizer")
check("window._adHomeVideo391=_adHomeVideo391" in src and
      "window._adHomeMedia395=_adHomeMedia395" in src and
      "hp395=setTimeout(function()" in src,
      "frozen Home video/WBT painters remain called through trailing schedules")


native = between("static CFAbsoluteTime gSweepDeadline", "// ─── sweep a cell as it comes into view",
                 "bounded native sweep")
for token in (
    "gSweepAbort451", "++gSweepNodes > 480", "(gSweepNodes & 7) == 0",
    "gSweepDeadline = t0 + budget451", "gSweepEpoch451",
    "step451<count451 && !gSweepAbort451",
):
    check(token in native or token in src, f"native sweep contract {token}")

settle = between("// A true trailing-edge settle.", "// SURFACE 4", "native scroll settle")
for token in (
    "lastMotion", "state->pending", "s.tracking || s.dragging || s.decelerating",
    "quiet < 0.22", "ADArmScrollSettle451(s, state)",
    "ADSweepTimed(s, ADInTabBarChain(s), \"scroll451\")",
    "ADScheduleNativeCompare451()",
):
    check(token in settle, f"scroll-settle contract {token}")
set_offset = between("- (void)setContentOffset:(CGPoint)offset", "%end", "content-offset hook")
check("ADSweepTimed(" not in set_offset and "ADArmScrollSettle451" in set_offset,
      "contentOffset records motion only; it never sweeps synchronously")

cells = between("// Recycled cells can enter layout in batches",
                "// ── TEXT CLASS PROBE", "weak frame-sliced cell queue")
for token in (
    "[NSHashTable weakObjectsHashTable]", "gADCellQueue451.count>=96",
    "ADMovingScrollForCell451", "ADArmCellDrain451(0.009)",
    '"cell451",0.00085', "ADQueueCellSweep451(self)",
):
    check(token in cells or token in src, f"cell convergence contract {token}")
check("ADSweepTimed(self" not in src,
      "cell layout cannot synchronously stack full native sweep budgets")
check(src.count("ADMaybeScheduleNativeCompare451(vv);") == 1,
      "Fabric image layout provides one quiet-only Compare acquisition signal")


if failures:
    print(f"performance-surfaces-451 fixture: FAIL ({len(failures)} contract(s))")
    sys.exit(1)
print("performance-surfaces-451 fixture: PASS (frozen UI retained; cross-window white Compare badge; authored Home color; bounded frame-sliced convergence)")

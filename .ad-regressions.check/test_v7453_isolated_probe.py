from pathlib import Path
import subprocess
R=Path(__file__).resolve().parents[1]
s=(R/'src/ADUniversalUIProbe7362.inc').read_text()
# Handler, document-start listener and every native evaluation must share the world.
assert 'worldWithName:@"AmazonDarkUIProbe7453"' in s
assert 'contentWorld:ADUIProbeWorld7453() name:@"adUniversalUI7433"' in s
assert 'forMainFrameOnly:NO inContentWorld:ADUIProbeWorld7453()' in s
assert s.count('[wv evaluateJavaScript:')==1
assert 'inFrame:nil inContentWorld:ADUIProbeWorld7453() completionHandler:completion' in s
router=s[s.index('static void ADUIProcessWebViews7364'):s.index('static void ADUIScanNativeAxis7364')]
assert 'gADUIFullHasPDP7451' in router
# v7.470 keeps the isolated world but restores the product-specific no-scroll branch.
assert 'ADUIEnsurePDPScrollable7456(wv,' in router
assert 'ADUIScanWebViewFull7364(wv,index,path,cap,nextWeb)' in router
full=s[s.index('static void ADUIScanWebViewFull7364'):s.index('static BOOL ADUIURLIsPDP7451')]
assert 'startRoot(NO);' in full
assert "if([kind hasPrefix:@\"root\"]){" in full and 'runFinalInventory();return;' in full
assert 'ADUIScanPDPStreaming7451(wv,index,path,cap,^' in full
finish=s[s.index('static void ADUIFinishCapture7364'):s.index('static void ADCaptureUniversalUIProbe7362')]
assert 'ADUINativeSnapshotAsync' not in finish
assert 'WEB_WALK_COVERAGE' in s
# Theme just the probe-proven product media leaf; no semantic color changes.
t=(R/'src/Tweak.xm').read_text()
rule=t[t.index('#dp#dp #newerVersionFeature .nevaMobImage img{'):].split('}',1)[0]
assert 'brightness(%.3f)' in rule and 'mix-blend-mode:normal' in rule
assert 'color:' not in rule and 'background:' not in rule
subprocess.run(['node',str(R/'tests/probe_walk7453.cjs'),str(R)],check=True)

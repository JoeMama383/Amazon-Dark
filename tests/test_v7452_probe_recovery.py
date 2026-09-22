from pathlib import Path
import subprocess
R=Path(__file__).resolve().parents[1]
s=(R/'src/ADUniversalUIProbe7362.inc').read_text()
attach=s[s.index('static void ADUIProbeAttach7362(WKUserContentController *ucc){'):s.index('static void ADUIAppendTerminal7364')]
assert attach.index('addScriptMessageHandler') < attach.index('if(old&&')
router=s[s.index('static void ADUIProcessWebViews7364'):s.index('static void ADUIScanNativeAxis7364')]
assert router.index('ADUIProbeAttach7362') < router.index('ADUIScanPDPStreaming7451') < router.index('ADUIScanWebViewFull7364')
assert '[wv.scrollView setContentOffset:original' not in s
assert '[sv layoutIfNeeded]' not in s
assert 'WEB_SCROLL_FAILURE details=' in s
assert 'gADMainStreamCapture7452 isEqualToString:capture' in s
subprocess.run(['node',str(R/'tests/probe_stream7452.cjs'),str(R)],check=True)

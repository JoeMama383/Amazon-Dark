from pathlib import Path
R=Path(__file__).resolve().parents[1]
s=(R/'src/ADUniversalUIProbe7362.inc').read_text()
# Regression: v7.470 silently replaced requested automatic scanning with manual-only
# sampling and a capture-phase scroll listener. Neither may reenter the product path.
for retired in ['ADUIScanPDPManual7455', 'pdp-manual-scroll-signal', 'gADPDPManualPending7455']:
    assert retired not in s
for retired in ['ADPDPManualTracker7455.js.inc','ADPDPManualSample7455.js.inc']:
    assert not (R/'src'/retired).exists()
router=s[s.index('static void ADUIProcessWebViews7364'):s.index('static void ADUIScanNativeAxis7364')]
assert 'ADUIEnsurePDPScrollable7456' in router and router.count('ADUIScanWebViewFull7364')==2
print('PASS: retired manual-only PDP path; automatic walk is gated by verified modal unlock')

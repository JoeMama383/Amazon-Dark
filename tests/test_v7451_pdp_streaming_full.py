from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/ADUniversalUIProbe7362.inc').read_text()
J=(R/'src/ADPDPMainStream7451.js.inc').read_text()
T=(R/'src/Tweak.xm').read_text()
C=(R/'layout/DEBIAN/control').read_text()

assert 'Version: 7.451~pdp-streaming-full' in C
assert '#define AD_VERSION "v7.451-pdp-streaming-full"' in T

# The failed v7.450 path recursively re-entered evaluateJavaScript once per tiny DOM chunk.
# PDP v7.451 must launch exactly one finite page-side stream and finish from script messages.
pdp=S[S.index('static NSString *ADPDPStreamJS7451'):S.index('static void ADUIProcessWebViews7364')]
assert '#include "ADPDPMainStream7451.js.inc"' in pdp
assert '[wv evaluateJavaScript:ADPDPStreamJS7451(capture)' in pdp
assert 'ADUIEvalAppend7364' not in pdp
assert '__adUIProbeContinue7446' not in pdp
assert 'PDP_STREAM_START_ACK transport=WKScriptMessageHandler no-per-chunk-evaluateJavaScript' in pdp

# Main-frame streaming completion is driven by the existing WKScriptMessageHandler,
# independently from cross-frame payload accounting.
handler=S[S.index('- (void)userContentController:'):S.index('@end', S.index('- (void)userContentController:'))]
for tok in ['pdp-stream-full','message.frameInfo.mainFrame','gADPDPStreamBatches7451','gADPDPStreamDone7451','PDP_STREAM_COMPLETE']:
    assert tok in handler, tok
assert 'if(!pdpMain)gADUIFramePayloads7446++' in handler

# The page-side scanner is finite, read-only, time-sliced and performs a cheap seen-node
# catch-up instead of scroll-driving the product renderer.
for tok in ["phase:'pdp-stream-full'", "setTimeout(slice,200)", 'state.pass=1', 'WeakSet', 'maxNodes=60000',
            "handler.postMessage", "frameId:'main-pdp-7451'", "pending.length>=24"]:
    assert tok in J, tok
for bad in ['scrollTo(', '.scrollTop=', '.scrollLeft=', 'requestAnimationFrame(', 'MutationObserver(', "addEventListener('scroll'"]:
    assert bad not in J, bad

# The streaming scanner must retain full technical paint coverage, not degrade into a
# viewport-only sampler.
for tok in ['getComputedStyle(el)', "getComputedStyle(el,'::before')", "getComputedStyle(el,'::after')",
            'getBoundingClientRect()', 'paintRisk(el,cs,tm)', 'media(el,cs)', 'scrollables.push',
            "document.createTreeWalker(document.documentElement,1)"]:
    assert tok in J, tok

print('PASS: v7.451 PDP FULL streams a finite full-document read-only scan without recursive WebKit evaluation')

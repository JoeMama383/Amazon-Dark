from pathlib import Path
import re
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text()
SB=(R/'src/AmazonDarkSB.xm').read_text()
C=(R/'layout/DEBIAN/control').read_text()
UI=(R/'scripts/ui-probe.sh').read_text(); SK=(R/'scripts/skeleton-probe.sh').read_text()
assert 'Version: 7.450~pdp-readonly-full' in C
assert '#define AD_VERSION "v7.450-pdp-readonly-full"' in S
assert 'VER=7.450' in UI and 'AD_PROBE_VERSION=7.450' in SK

# Performance architecture: production must stay free of recurring traversal machinery.
for bad in ('new MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'", 'createTreeWalker('):
    assert bad not in S,bad
# Keep the one generic querySelectorAll call confined to the existing deterministic preference/style path;
# this pass must not add a second call site.
assert S.count('querySelectorAll(')<=1

# PDP frame delivery: one cached strength-specific program, same-document fast path,
# PDP-main gate, cached page content world, and one UCC bridge receipt.
for tok in ('gADForcedPDPFrameThemeCached7448','gADForcedPDPFrameThemeStrength7448',
            '__ad7440FrameOwnerKey','ad7440-already',
            'static id world=nil; static dispatch_once_t once','getElementById(\'dp\')'):
    assert tok in S,tok
bridge=S[S.index('static NSString *ADFrameOwnerTriggerJS7440'):S.index('static id ADPageWorld7440')]
assert 'window-load' in bridge and 'document-start' not in bridge
assert "addEventListener('load'" in bridge and 'DOMContentLoaded' in bridge and 'pageshow' in bridge

# Explicit probe breadth-first traversals use cursor queues; front-removal shifts are gone.
assert 'removeObjectAtIndex:0' not in S
assert 'removeObjectAtIndex:0' not in SB
assert S.count('while(seen<q.count') >= 5

# Redundant post-v7.388 CSS shorthands should stay consolidated. Do not apply this
# to the frozen legacy programs whose semantic hashes are independently regression-locked.
def fn(name,next_name=None):
    a=S.index('static NSString *'+name)
    b=S.index('static NSString *'+next_name,a) if next_name else len(S)
    return S[a:b]
blocks=[
 fn('ADProductShareThemeJS7403','ADProductShareTWBJS7403'),
 fn('ADProductShareTWBJS7403','ADShareProbeSuppressJS7403'),
 fn('ADShareProbeSuppressJS7403','ADProductScrollPolishJS7404'),
 fn('ADProductScrollPolishJS7404','ADProductScrollVideoBorderJS7405'),
 fn('ADProductScrollVideoBorderJS7405','ADPDPCompletionJS7405'),
 fn('ADPDPCompletionJS7405','ADPDPCompletionTWBJS7405'),
 fn('ADPDPCompletionTWBJS7405','ADPDPSafeFrameJS7432'),
 fn('ADPDPSafeFrameJS7432','ADPDPUICompletionJS7439'),
 fn('ADPDPUICompletionJS7439','ADForcedPDPFrameThemeJS7440'),
 fn('ADForcedPDPFrameThemeJS7440','ADFrameOwnerTriggerJS7440'),
 fn('ADPDPMainResidualJS7440','ADAddressManagementJS7412'),
 fn('ADAddressManagementJS7412','ADCoreWebJS7271')]
post=''.join(blocks)
for pat in (r'background:([^;]+)!important;background-color:\1!important',
            r'background:([^;]+)!important;background-image:none!important'):
    assert not re.search(pat,post),pat

# Size gates are deliberately looser than exact values so comments/identity maintenance can change,
# but future feature work cannot silently restore the pre-pass source footprint.
assert len(S.encode()) < 856000, len(S.encode())
assert len((R/'src/ADUniversalUIProbe7362.inc').read_bytes()) < 76000  # v7.450 adds a PDP-only read-only diagnostic branch; production Tweak size gate remains unchanged
assert len(SB.encode()) < 19200
print('PASS: v7.450 preserves performance-consolidation recurring-work invariants, PDP frame caching, linear probe queues, and production source-size gates')

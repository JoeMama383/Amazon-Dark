from pathlib import Path
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text()
import json
JRAW=(R/'src/ADReturnsTheme7480.js.inc').read_text()
J=''.join(json.loads(line) for line in JRAW.splitlines() if line.strip())
N=(R/'src/ADReturnsNative7480.inc').read_text()
CMD=(R/'COMMANDS.md').read_text()

assert len(T.encode()) < 856000, len(T.encode())
assert '#include "ADReturnsTheme7480.js.inc"' in T
assert 'ADReturnsThemeJS7480()' in T
assert '#include "ADReturnsNative7480.inc"' in T
assert 'ADNeutralizeBottomFadeSibling7480(v);' in T

# FULL r1 main Return Instructions owners.
for token in (
    'print-label-button-app',
    'share-label-secondary-view-trigger',
    'return-deadline-display',
    'printable-section table.a-bordered.a-horizontal-stripes.auto-width-and-side-margin',
    '@media screen',
    'background:#000!important',
    'border:1px solid #747a7c!important',
    'background:#494d4d!important',
    'filter:brightness(.42)!important',
): assert token in J, token

# Preserve the blue alert ring: the deadline rule changes floor/copy only, not border color.
deadline=J[J.index('return-deadline-display'):J.index('post-send-snail-mail-section')]
assert 'background:#000!important' in deadline
assert 'border-color:#494d4d' not in deadline
assert 'border:1px solid' not in deadline

# FULL r2/r3 email secondary-view owners.
for token in (
    'share-label-popover-input-section',
    'email-recipient-selection',
    'a-popover-wrapper',
    'a-popover-inner',
    'a-accordion-inner',
    'a-input-text-wrapper',
    'textarea#share-email',
    'button-share',
    'a-checkbox-label',
): assert token in J, token

# Dynamic link/symbol colors are not flattened globally.
assert 'a *{-webkit-text-fill-color:currentColor!important;}' in J
assert '.a-icon-checkbox{filter:none!important' in J

# Exact native gradient sibling gate from FULL r1.
for token in ('CAGradientLayer','ADBrightNeutralUIView708','f.size.width<vr.size.width*0.90','f.size.height<40.0','f.size.height>110.0','sib.alpha=0.0'):
    assert token in N, token

# No recurring production work introduced.
for bad in ('MutationObserver(', 'setInterval(', 'requestAnimationFrame(', 'addEventListener(\'scroll\''):
    assert bad not in J

# Standing handoff contract: separated probes, no status commands.
for h in ('## FULL — v7.480','## VIEWPORT — v7.480','## TRANSITION — v7.480'):
    assert h in CMD
assert ' status' not in CMD
print('PASS: v7.480 Returns main + email secondary views are probe-backed and preserve semantic colors')

from pathlib import Path
import json
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text()
C=(R/'layout/DEBIAN/control').read_text()
CMD=(R/'COMMANDS.md').read_text()
J=''.join(json.loads(line) for line in (R/'src/ADReturnsTheme7480.js.inc').read_text().splitlines() if line.strip())

assert 'Version: 7.488~returns-geometry-header-cta' in C
assert '#define AD_VERSION "v7.488-returns-geometry-header-cta"' in T
for h in ('## FULL — v7.488','## VIEWPORT — v7.488','## TRANSITION — v7.488'):
    assert h in CMD, h
assert ' status' not in CMD.lower()

# ORC warning: theme only its floor; do not redraw/re-size/recolor Amazon's authored warning frame.
warning = '#a-page:has(#orc-items-details-and-content-section) :is(.a-alert-warning,.a-alert-warning>.a-alert-container,.a-alert-warning .a-alert-container){background:#000!important;}'
assert warning in J
assert 'border-color:#e47911!important' not in J
assert 'box-shadow:inset 4px 0 0 #e47911!important' not in J

# Returns-history neutral copy must include the end-of-history/header family, not only item cards.
assert '.returns-history-section :is(h1,h2,h3,h4,h5,h6,.returns-history-header-section,.returns-history-header-section *' in J
assert 'color:#fff!important;-webkit-text-fill-color:#fff!important;' in J

# Recommendations CTA: recolor paint only; preserve button geometry (no width/radius/padding/border-width rule).
cta = '#a-page:has(.your-returns-page-container.instrumentation) .recommendation-horizontal-section :is(.a-button,.a-button-primary,.a-button-base){background:#000!important;border-color:#747a7c!important;box-shadow:none!important;color:#fff!important;-webkit-text-fill-color:#fff!important;}'
assert cta in J
assert '.recommendation-horizontal-section :is(.a-button,.a-button-primary,.a-button-base) :is(.a-button-inner,.a-button-text){background:#000!important;border-color:#747a7c!important;box-shadow:none!important;color:#fff!important;-webkit-text-fill-color:#fff!important;}' in J
for bad in ('width:', 'height:', 'border-radius:', 'padding:'):
    assert bad not in cta

# Do not add recurring production DOM machinery.
for bad in ('MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in J, bad

print('PASS: v7.488 preserves authored ORC warning geometry/color and fixes Returns history headers + recommendation CTAs')

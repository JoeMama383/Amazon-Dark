from pathlib import Path
import json
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text()
J=''.join(json.loads(line) for line in (R/'src/ADReturnsTheme7480.js.inc').read_text().splitlines() if line.strip())
N=(R/'src/ADReturnsNative7480.inc').read_text()
CMD=(R/'COMMANDS.md').read_text()

# FULL r1 ORC owners.
for token in (
    '#orc-items-details-and-content-section', '#consumed-unit-section', '#orc-returning-items-section',
    '#MobileHeaderTextBoldWidgetElement', '.a-alert-warning', '.a-button-base',
    'background:#303335!important', 'border:1px solid #747a7c!important',
    'filter:brightness(.42)!important',
): assert token in J, token

# FULL r2 Your Returns owners.
for token in (
    '.your-returns-page-container.instrumentation', '.active-return-card', '.see-all-active-returns-card',
    '.returns-history-section', '.recommendations-section', '.recommendation-horizontal-section',
    '.item-return-history-card-widget-link', '.a-price,.a-text-price,.a-price *',
): assert token in J, token

# Dynamic colors are not globally flattened: links/prices retain currentColor.
assert '#a-page:has(.your-returns-page-container.instrumentation) a{-webkit-text-fill-color:currentColor!important;}' in J
assert '#a-page:has(.your-returns-page-container.instrumentation) :is(.a-price,.a-text-price,.a-price *){-webkit-text-fill-color:currentColor!important;}' in J
assert '.a-icon-alert{filter:none!important' in J

# FULL r3: collapse the 42pt AUI fade/divider box to one gray pixel and kill pseudo fades.
for token in (
    '.a-divider.a-divider-section{height:1px!important;min-height:1px!important;',
    '.a-divider.a-divider-section>.a-divider-inner{height:1px!important;min-height:1px!important;',
    'content:none!important;display:none!important;background:none!important;box-shadow:none!important;',
): assert token in J, token

# Native exact sibling remains suppressed even after its background has already become transparent.
assert 'if(!gradient)continue;' in N
assert 'if(!gradient||!ADBrightNeutralUIView708(sib))continue;' not in N
assert 'sib.alpha=0.0' in N

# Performance contract: all new web work is declarative.
for bad in ('MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in J, bad

# Build/handoff identity and standing probe formatting contract.
assert '#define AD_VERSION "v7.482-pdp-immersive-review-profile-theme"' in T
for h in ('## FULL — v7.482','## VIEWPORT — v7.482','## TRANSITION — v7.482'):
    assert h in CMD, h
assert ' status' not in CMD
assert len(T.encode()) < 856000, len(T.encode())
print('PASS: v7.482 themes FULL r1/r2 Returns owners and collapses the r3 fade/divider without flattening semantic colors')

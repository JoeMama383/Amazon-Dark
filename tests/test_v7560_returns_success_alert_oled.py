"""v7.560: probe-backed Returns success alert OLED fill with green rail preservation."""
from pathlib import Path
import json
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text()
C=(R/'layout/DEBIAN/control').read_text()
J=''.join(json.loads(line) for line in (R/'src/ADReturnsTheme7480.js.inc').read_text().splitlines() if line.strip())
assert 'Version: 7.560~returns-success-alert-oled' in C
assert '#define AD_VERSION "v7.560-returns-success-alert-oled"' in T
g='#a-page:has(#orc-items-details-and-content-section)'
outer=g+' .a-box.a-alert.a-alert-success'
inner=outer+'>.a-box-inner.a-alert-container'
assert outer+'{background:#000!important;color:#fff!important;}' in J
assert inner+'{background:#000!important;color:#fff!important;}' in J
text=outer+' :is(.a-alert-heading,.a-alert-content,.a-alert-content span,.a-alert-content div,.a-list-item,.a-text-left,.a-color-base,.a-color-secondary,strong,b){color:#fff!important;-webkit-text-fill-color:#fff!important;}'
assert text in J
# The exact captured success-alert owner must not have its Amazon green rail/border rewritten.
for selector in (outer,inner):
    block=J.split(selector+'{',1)[1].split('}',1)[0]
    assert 'border:' not in block and 'border-color:' not in block
    assert 'border-radius:' not in block and 'transform:' not in block
# Existing semantic link preservation and old Returns family remain intact.
assert g+' a,'+g+' a *{-webkit-text-fill-color:currentColor!important;}' in J
for token in ('#consumed-unit-section','#orc-returning-items-section','.a-alert-warning'):
    assert token in J
# New owner stays declarative-only.
for bad in ('MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'", 'setTimeout('):
    assert bad not in J
print('PASS: v7.560 OLEDs exact Returns success-alert planes, keeps copy white, and preserves authored green rail/border')

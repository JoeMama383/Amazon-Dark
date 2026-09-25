from pathlib import Path
import json
R=Path(__file__).resolve().parents[1]
J=''.join(json.loads(line) for line in (R/'src/ADNewMenus7482.js.inc').read_text().splitlines() if line.strip())
T=(R/'src/Tweak.xm').read_text()
C=(R/'layout/DEBIAN/control').read_text()
CMD=(R/'COMMANDS.md').read_text()

assert 'Version: 7.486~book-overlay-fade-removal' in C
assert '#define AD_VERSION "v7.486-book-overlay-fade-removal"' in T

# v7.480 r1/r2 and v7.485 r1 all show the same 48px gradient as the AFTER
# pseudo of the exact immersive PUTB carousel card. The parent advertises that
# overlay family explicitly with image-block-putb-grey-overlay-enabled.
sel='.a-popover.putb-immersive-view-gallery #putb_immersive_view_carousel.image-block-putb-grey-overlay-enabled li.putb-card::after'
assert sel in J
rule=J.split(sel,1)[1].split('}',1)[0]
for token in (
    'content:none!important',
    'display:none!important',
    'width:0!important',
    'height:0!important',
    'background:none!important',
    'background-image:none!important',
    'box-shadow:none!important',
    'opacity:0!important',
):
    assert token in rule, token

# Do not remove/flatten the card itself or authored selected pagination dot.
assert '.a-popover.putb-immersive-view-gallery li.putb-card{background:#000!important;border:1px solid #494d4d!important' in J
assert '#putb-pagination-dots li.a-selected{background:#2162a1!important;border-color:#2162a1!important;}' in J

for bad in ('MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in J, bad

for h in ('## FULL — v7.486','## VIEWPORT — v7.486','## TRANSITION — v7.486'):
    assert h in CMD, h
assert ' status' not in CMD.lower()
print('PASS: v7.486 removes the probe-proven 48px PUTB card ::after gradient from both immersive book menus')

from pathlib import Path
import json
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text()
J=''.join(json.loads(line) for line in (R/'src/ADNewMenus7482.js.inc').read_text().splitlines() if line.strip())
C=(R/'layout/DEBIAN/control').read_text()
CMD=(R/'COMMANDS.md').read_text()
UI=(R/'scripts/ui-probe.sh').read_text()
SK=(R/'scripts/skeleton-probe.sh').read_text()
V=(R/'scripts/validate.sh').read_text()

assert 'Version: 7.494~orders-exact-fix' in C
assert '#define AD_VERSION "v7.494-orders-exact-fix"' in T
assert 'VER=7.494' in UI
assert 'AD_PROBE_VERSION=7.494' in SK
assert len(T.encode()) < 856000, len(T.encode())
for h in ('## FULL — v7.494','## VIEWPORT — v7.494','## TRANSITION — v7.494'):
    assert h in CMD, h
assert ' status' not in CMD
assert '### Arm' in CMD and '### Export' in CMD
assert 'tests/test_v7493_orders_endtext_ci_repair.py' in V

root='section.your-orders-mobile-content-container.aok-relative.js-yo-container'
assert root in J

# v7.493 FULL r2 exact evidence:
# .yo-mobile-atf => 5px rgb(213,217,217) bottom border; make only its color OLED.
assert root+' .yo-mobile-atf{' in J
assert 'border-bottom-color:#000!important;' in J
# form.search-bar.js-search-bar => 5px gray bottom border; collapse exact owner to normal 1px.
assert root+' form.search-bar.js-search-bar{' in J
assert 'border-bottom-width:1px!important;border-bottom-style:solid!important;border-bottom-color:#494d4d!important;' in J
# span.product-image__qty => transparent fill + light border + dark text; exact owner gets project badge styling.
assert root+' #past-purchases-section-id .past-purchase-tile .product-image__qty{' in J
assert 'background:#303335!important;border:1px solid #747a7c!important;color:#fff!important;-webkit-text-fill-color:#fff!important;box-shadow:none!important;' in J

# Retain the established split search seam without adding extra frame work.
assert root+' .a-input-text-wrapper.search-bar__input.js-search-bar-input{' in J
assert 'border-right-width:0!important;' in J
assert root+' .search-bar__open-filter-link-container.js-open-filter-link-container{' in J
assert 'border-left:1px solid #747a7c!important;box-shadow:none!important;' in J

# Retained verified fixes.
for tok in (
    '#your-orders-mobile-content-container__end-of-items-divider>.a-size-small.a-color-base',
    '[class*="_timely-reminders-information-tile_style_tileContainer"]',
    '#a-white{background:#000!important;background-color:#000!important;box-shadow:none!important;}',
):
    assert tok in J, tok

for bad in ('MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in J, bad

print('PASS: v7.494 uses FULL-r2 exact owners for Orders white strip, search 5px seam, and product quantity badge')

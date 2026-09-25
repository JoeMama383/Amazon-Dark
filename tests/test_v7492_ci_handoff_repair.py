from pathlib import Path
import json
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text()
J=''.join(json.loads(line) for line in (R/'src/ADNewMenus7482.js.inc').read_text().splitlines() if line.strip())
C=(R/'layout/DEBIAN/control').read_text()
CMD=(R/'COMMANDS.md').read_text()
UI=(R/'scripts/ui-probe.sh').read_text()
SK=(R/'scripts/skeleton-probe.sh').read_text()

assert 'Version: 7.492~ci-handoff-repair' in C
assert '#define AD_VERSION "v7.492-ci-handoff-repair"' in T
assert 'VER=7.492' in UI
assert 'AD_PROBE_VERSION=7.492' in SK
assert len(T.encode()) < 856000, len(T.encode())
for h in ('## FULL — v7.492','## VIEWPORT — v7.492','## TRANSITION — v7.492'):
    assert h in CMD, h
assert ' status' not in CMD
assert '### Arm' in CMD and '### Export' in CMD

root='section.your-orders-mobile-content-container.aok-relative.js-yo-container'
assert root in J

for tok in (
    '.page-title-padding-container',
    '.past-purchases-section-header__title',
    '.past-purchases-section-header__sub-title',
    'background:#000!important;color-scheme:dark!important',
    'color:#fff!important;-webkit-text-fill-color:#fff!important',
):
    assert tok in J, tok

for tok in (
    'form.search-bar.js-search-bar',
    '.a-input-text-wrapper.search-bar__input.js-search-bar-input',
    'button.search-bar__button',
    '.search-bar__open-filter-link-container.js-open-filter-link-container',
    'img.search-bar__icon{',
    'filter:none!important;-webkit-filter:none!important;mix-blend-mode:normal!important;opacity:1!important;',
    '.search-bar__open-filter-link .a-icon-touch-link{',
    'filter:brightness(0) invert(1)!important;-webkit-filter:brightness(0) invert(1)!important;',
    'border-right-width:0!important;',
    'border-left:1px solid #747a7c!important;border-top-width:1px!important;border-right-width:1px!important;border-bottom-width:1px!important;box-shadow:none!important;',
):
    assert tok in J, tok

for tok in (
    '[class*="_timely-reminders-asin-tile_style_tile-container"]',
    '[class*="_timely-reminders-returns-tile_style_tile-container"]',
    '#past-purchases-section-id .past-purchase-tile',
    '.past-purchase-tile__asin-information',
    '.past-purchase-tile__asin-thumbnail',
    'border-color:#494d4d!important',
    '[class*="_timely-reminders-information-tile_style_tileContainer"]',
    'background:#123552!important;border:0!important;outline:0!important;box-shadow:none!important;',
    '[class*="_timely-reminders-information-tile_style_divider"]',
    'background:#000!important;border-color:#000!important;box-shadow:none!important;',
):
    assert tok in J, tok

assert 'img:not(.search-bar__icon)' in J
assert 'filter:brightness(.42)!important' in J

for tok in (
    '#past-purchases-section-id .past-purchase-tile :is([class*="badge"],[class*="quantity"],[class*="count"])',
    'background:#303335!important;border:1px solid #747a7c!important;color:#fff!important;-webkit-text-fill-color:#fff!important;box-shadow:none!important;',
):
    assert tok in J, tok

assert '#a-white{background:#000!important;background-color:#000!important;box-shadow:none!important;}' in J
for forbidden in ('#a-white{display:', '#a-white{opacity:', '#a-white{height:', '#a-white{width:', '#a-white{transform:'):
    assert forbidden not in J, forbidden

for bad in ('MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in J, bad

print('PASS: v7.492 follow-up themes the blue info tiles, search-bar seam, and quantity bubble while retaining the v7.490 Orders/transition ownership')

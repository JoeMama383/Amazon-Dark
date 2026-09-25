from pathlib import Path
import json
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text()
J=''.join(json.loads(line) for line in (R/'src/ADNewMenus7482.js.inc').read_text().splitlines() if line.strip())
C=(R/'layout/DEBIAN/control').read_text()
CMD=(R/'COMMANDS.md').read_text()
UI=(R/'scripts/ui-probe.sh').read_text()
SK=(R/'scripts/skeleton-probe.sh').read_text()

assert 'Version: 7.490~orders-book-transition' in C
assert '#define AD_VERSION "v7.490-orders-book-transition"' in T
assert 'VER=7.490' in UI
assert 'AD_PROBE_VERSION=7.490' in SK
assert len(T.encode()) < 856000, len(T.encode())
for h in ('## FULL — v7.490','## VIEWPORT — v7.490','## TRANSITION — v7.490'):
    assert h in CMD, h
assert ' status' not in CMD.lower()

# Exact page fingerprint from FULL r2.
root='section.your-orders-mobile-content-container.aok-relative.js-yo-container'
assert root in J

# Headers/floors.
for tok in (
    '.page-title-padding-container',
    '.past-purchases-section-header__title',
    '.past-purchases-section-header__sub-title',
    'background:#000!important;color-scheme:dark!important',
    'color:#fff!important;-webkit-text-fill-color:#fff!important',
):
    assert tok in J, tok

# Exact search-family owners from FULL r2. Blue magnifier is explicitly preserved,
# while the touch-link chevron becomes white.
for tok in (
    'form.search-bar.js-search-bar',
    '.a-input-text-wrapper.search-bar__input.js-search-bar-input',
    'button.search-bar__button',
    '.search-bar__open-filter-link-container.js-open-filter-link-container',
    'img.search-bar__icon{',
    'filter:none!important;-webkit-filter:none!important;mix-blend-mode:normal!important;opacity:1!important;',
    '.search-bar__open-filter-link .a-icon-touch-link{',
    'filter:brightness(0) invert(1)!important;-webkit-filter:brightness(0) invert(1)!important;',
):
    assert tok in J, tok

# Probe-visible white top tiles and purchase-history cards are darkened without
# touching the authored blue information-tile floor.
for tok in (
    '[class*="_timely-reminders-asin-tile_style_tile-container"]',
    '[class*="_timely-reminders-returns-tile_style_tile-container"]',
    '#past-purchases-section-id .past-purchase-tile',
    '.past-purchase-tile__asin-information',
    '.past-purchase-tile__asin-thumbnail',
    'border-color:#494d4d!important',
):
    assert tok in J, tok
assert '[class*="_timely-reminders-information-tile_style_tileContainer"]' not in J

# Images/rasters are tamed, with the search magnifier excluded.
assert 'img:not(.search-bar__icon)' in J
assert 'filter:brightness(.42)!important' in J

# v7.489 expanded TRANSITION capture identified the actual bright plane twice: DIV#a-white.
# Production ownership is declarative paint-only; no transition geometry/opacity/timing writes.
assert '#a-white{background:#000!important;background-color:#000!important;box-shadow:none!important;}' in J
for forbidden in ('#a-white{display:', '#a-white{opacity:', '#a-white{height:', '#a-white{width:', '#a-white{transform:'):
    assert forbidden not in J, forbidden

# No steady-state runtime machinery added.
for bad in ('MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in J, bad

print('PASS: v7.490 probe-backed Your Orders theming owns headers, white cards, chevrons and media while preserving the blue magnifier')

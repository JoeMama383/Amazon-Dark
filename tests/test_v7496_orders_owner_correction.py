from pathlib import Path
import json
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text()
J=''.join(json.loads(line) for line in (R/'src/ADNewMenus7482.js.inc').read_text().splitlines() if line.strip())
C=(R/'layout/DEBIAN/control').read_text()
UI=(R/'scripts/ui-probe.sh').read_text()
SK=(R/'scripts/skeleton-probe.sh').read_text()
V=(R/'scripts/validate.sh').read_text()

assert 'Version: 7.496~orders-owner-correction' in C
assert '#define AD_VERSION "v7.496-orders-owner-correction"' in T
assert 'VER=7.496' in UI
assert 'AD_PROBE_VERSION=7.496' in SK
assert 'AD_PROBE_NAME=AmazonDark-v7.496' in SK
assert 'tests/test_v7495_orders_followup_r3.py' in V

root='section.your-orders-mobile-content-container.aok-relative.js-yo-container'
# Prime info tile: one parent tame only, authored blue retained, child filters cleared.
parent=root+' [class*="_timely-reminders-information-tile_style_tileContainer"]{'
assert parent in J
assert 'filter:brightness(.42)!important;-webkit-filter:brightness(.42)!important;' in J
assert 'background:#123552!important;' not in J
assert 'box-shadow:inset 0 0 0 9999px' not in J
assert root+' [class*="_timely-reminders-information-tile_style_tileContainer"] :is(img,[class*="_timely-reminders-information-tile_style_imageContainer"]' in J
assert 'filter:none!important;-webkit-filter:none!important;box-shadow:none!important;' in J

# Search: the form owns both full-width rails; gray children fill the 55px interior.
assert root+' form.search-bar.js-search-bar{' in J
for tok in ('height:57px!important;','border-top:1px solid #494d4d!important;','border-bottom:1px solid #494d4d!important;','background:#181a1b!important;'):
    assert tok in J, tok
assert root+' :is(.a-input-text-wrapper.search-bar__input.js-search-bar-input,button.search-bar__button){' in J
assert 'height:55px!important;min-height:55px!important;background:#181a1b!important;' in J
assert root+' .search-bar__open-filter-link-container.js-open-filter-link-container{' in J
assert 'top:1px!important;height:55px!important;min-height:55px!important;' in J
assert 'border-left:0!important;' in J
assert root+' .search-bar__open-filter-link-container.js-open-filter-link-container::before{' in J
assert 'top:5px!important;bottom:5px!important;width:1px!important;background:#747a7c!important;' in J
assert root+' .yo-mobile-atf{' in J
assert '.yo-mobile-atf::after' not in J

# Qty: exact 20x20 grid center; no flex/baseline dependence.
assert root+' .product-image__qty{' in J
for tok in ('display:grid!important;','place-items:center!important;','width:20px!important;','height:20px!important;','line-height:1!important;','border-radius:50%!important;'):
    assert tok in J, tok

# Visible medium raster is the inline APE family, not the footer APE.
assert root+' [id^="ape_YourOrders_myo-inline-"][id$="_wrapper"],' in J
assert root+' [id^="ape_YourOrders_myo-inline-"][id$="_placement"]::before{' in J
assert 'height:2px!important;background:#000!important;z-index:2147483647!important;' in J
assert '#your-orders-mobile-content-container__adplacement-slot iframe' not in J

for bad in ('MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in J, bad
print('PASS: v7.496 uses the correct Orders owners for full-tile taming, search rails/divider geometry, quantity centering, and inline-raster seam masking')

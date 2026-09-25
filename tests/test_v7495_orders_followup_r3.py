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

assert 'Version: 7.495~orders-followup-r3' in C
assert '#define AD_VERSION "v7.495-orders-followup-r3"' in T
assert 'VER=7.495' in UI
assert 'AD_PROBE_VERSION=7.495' in SK
for h in ('## FULL — v7.495','## VIEWPORT — v7.495','## TRANSITION — v7.495'):
    assert h in CMD, h
assert ' status' not in CMD
assert '### Arm' in CMD and '### Export' in CMD
assert 'tests/test_v7494_orders_exact_fix.py' in V

root='section.your-orders-mobile-content-container.aok-relative.js-yo-container'
assert root in J
prime = root+' :is([class*="_timely-reminders-information-tile_style_tileContainer"],[class*="_timely-reminders-information-tile_style_container"],[class*="_timely-reminders-information-tile_style_tileContent"],[class*="_timely-reminders-information-tile_style_insightContainer"],[class*="_timely-reminders-information-tile_style_majorInsightContainer"],[class*="_timely-reminders-information-tile_style_insightGroup"],[class*="_timely-reminders-information-tile_style_segment"]){'
assert prime in J
assert 'box-shadow:inset 0 0 0 9999px rgba(0,0,0,.22)!important;' in J
assert 'background:#123552!important;' not in J
assert root+' .yo-mobile-atf{' in J
assert 'position:relative!important;border-bottom-color:#000!important;box-shadow:none!important;' in J
assert root+' .yo-mobile-atf::after{' in J
assert "content:''!important;position:absolute!important;left:0!important;right:0!important;bottom:0!important;height:1px!important;background:#494d4d!important;pointer-events:none!important;" in J
assert root+' form.search-bar.js-search-bar{' in J
assert 'border-bottom:0!important;box-shadow:none!important;' in J
assert root+' .search-bar__open-filter-link-container.js-open-filter-link-container{' in J
assert 'border-left:1px solid #747a7c!important;box-shadow:none!important;margin-bottom:6px!important;' in J
assert root+' #past-purchases-section-id .past-purchase-tile .product-image__qty{' in J
for tok in ('display:inline-flex!important;','align-items:center!important;','justify-content:center!important;','min-width:24px!important;','width:24px!important;','height:24px!important;','text-align:center!important;','border-radius:999px!important;'):
    assert tok in J, tok
assert root+' #your-orders-mobile-content-container__adplacement-slot,' in J
assert 'background:#000!important;box-shadow:none!important;overflow:hidden!important;border-top:0!important;' in J
assert root+' #your-orders-mobile-content-container__adplacement-slot iframe{' in J
assert 'display:block!important;position:relative!important;top:-1px!important;background:transparent!important;border:0!important;box-shadow:none!important;' in J
for bad in ('MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in J, bad
print('PASS: v7.495 preserves Prime tile color, moves the Orders underline to the row owner, centers the qty bubble, and crops the 1px raster seam')

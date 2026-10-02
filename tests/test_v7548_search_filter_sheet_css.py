from pathlib import Path
f=Path('src/ADNewMenus7482.js.inc').read_text()
assert 'v7.553 FULL r3 exact-owner search Filters sheet follow-up' in f
for token in [
    '#dropdown-content-s-all-filters',
    '.sf-filters-vtabs-tabs-container',
    '.s-vtabs-contents-container',
    '.sf-bottom-nav.sf-bottom-nav-current',
    '.sf-show-results',
    'background:#303335!important;background-color:#303335!important;border:1px solid #747a7c!important',
    'border-right:1px solid #494d4d!important',
    'border:0!important;border-top:0!important;border-bottom:0!important;box-shadow:none!important',
    'background:#000!important;background-color:#000!important;border:1px solid #747a7c!important;border-color:#747a7c!important;box-sizing:border-box!important;box-shadow:none!important;color:#fff!important'
]:
    assert token in f, token
assert 'body:has(#search) :is([class*=filter-sheet]' not in f
print('PASS: v7.553 uses the v7.548 FULL-probe exact Filters owners for gray option controls, one rail divider, divider-free footer, and OLED Show results')

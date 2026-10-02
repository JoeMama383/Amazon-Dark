from pathlib import Path
f=Path('src/ADNewMenus7482.js.inc').read_text()
for token in [
    'About You memory grid follow-up',
    'body:has(.memory-grid-container.mobile) .memory-grid-container.mobile{background:#000!important;background-color:#000!important;color-scheme:dark!important;}',
    '.import-memory-banner,.memory-item-container,.memory-create-button,.search-input-wrapper,.category-filter-button,.ai-mode-popover-container',
    '.import-memory-banner :is(.import-action-button,.a-link-normal,a,button){color:#5da8ff!important;-webkit-text-fill-color:#5da8ff!important;}',
    '.category-filter-button.selected,body:has(.memory-grid-container.mobile) .memory-grid-container.mobile .category-filter-button[aria-pressed=\\"true\\"]{border-color:#1c89e3!important',
    '.memory-item-container :is(.header,.value){color:#fff!important;-webkit-text-fill-color:#fff!important;}',
    '.search-input,.search-input::placeholder){color:#fff!important;-webkit-text-fill-color:#fff!important;opacity:1!important;}'
]:
    assert token in f, token
print('PASS: v7.550 themes the About You memory grid cards, pills, banner, and search controls while preserving dynamic link/selection accents')

from pathlib import Path
import json
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text()
JNEW=(R/'src/ADNewMenus7482.js.inc').read_text()
JRET=''.join(json.loads(line) for line in (R/'src/ADReturnsTheme7480.js.inc').read_text().splitlines() if line.strip())
C=(R/'layout/DEBIAN/control').read_text()
CMD=(R/'COMMANDS.md').read_text()

assert 'Version: 7.483~pdp-books-returns-followup' in C
assert '#define AD_VERSION "v7.483-pdp-books-returns-followup"' in T
for h in ('## FULL — v7.483','## VIEWPORT — v7.483','## TRANSITION — v7.483'):
    assert h in CMD, h
assert ' status' not in CMD.lower()

# PUTB follow-up: broad text whitening + fade collapse retained under the exact immersive owner.
for token in (
    '.a-popover.putb-immersive-view-gallery .putb-card-immersive-view :is(h1,h2,h3,h4,h5,h6,p,span,div,strong,b,li,.a-color-base,.a-color-secondary,.a-color-tertiary,.a-size-small,.a-size-base,.a-size-medium,.a-text-normal,.a-text-bold)',
    '.a-popover.putb-immersive-view-gallery .a-divider.a-divider-section{height:1px!important;min-height:1px!important;',
    '.a-popover.putb-immersive-view-gallery .a-divider.a-divider-section>.a-divider-inner::before,.a-popover.putb-immersive-view-gallery .a-divider.a-divider-section>.a-divider-inner::after{content:none!important;display:none!important;background:none!important;box-shadow:none!important;}',
):
    assert token in JNEW, token

# PDP related/similar book cards get explicit dark-copy cleanup while semantic colors survive.
for token in (
    '#dp#dp :is(#relatedProductZone4_feature_div,#similarities_feature_div,[id*=similarities],[id*=recommendation],[id*=relatedProductZone],[id*=rhf])',
    '.a-price,.a-price-whole,.a-price-symbol,.a-price-fraction,.a-offscreen',
    '.a-color-link,.a-color-price,[class*=prime],[class*=star],[class*=rating],[class*=badge]',
):
    assert token in JNEW, token

# Returns follow-up: printable text whitelist, warning orange restoration, and broader card copy whitening.
for token in (
    '.a-size-base,.a-size-medium,.a-size-small,.a-color-base,.a-color-secondary,.a-color-tertiary,ul.a-unordered-list,ul.a-unordered-list li,ul.a-unordered-list li>span,span,div,p,strong,b,em,td,th,li',
    'border-color:#e47911!important',
    'box-shadow:inset 4px 0 0 #e47911!important',
    '.active-return-card,.see-all-active-returns-card,.item-return-history-card,.recommendation-horizontal-section',
):
    assert token in JRET, token


# Customer service hybrid hub follow-up: exact hybrid-hub owner, gray cards/controls, white neutral copy, white search icon.
for token in (
    '#a-page:has(#hybrid-hub-app .search-bar-with-suggestions-container)',
    '#hybrid-hub-app :is(.entity-card,.entity-card-wrapper,.fs-holiday-banner,.fs-holiday-banner-content,.learn-more-section,.learn-more-footer,.fs-button,.action-button',
    '#hybrid-hub-app :is(svg,path,circle,line,polyline,rect){stroke:#fff!important;fill:#fff!important;color:#fff!important;}',
):
    assert token in JNEW, token

for bad in ('MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in JNEW, bad
    assert bad not in JRET, bad

print('PASS: v7.483 fixes PUTB book fades/text, PDP related-book dark copy, and returns text/orange warning follow-up')

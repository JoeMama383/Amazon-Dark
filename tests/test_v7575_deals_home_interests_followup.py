from pathlib import Path
import subprocess,tempfile

root=Path(__file__).resolve().parents[1]
menus=(root/'src/ADNewMenus7482.js.inc').read_text()
tweak=(root/'src/Tweak.xm').read_text()
for tok in (
    'v7.575 VIEWPORT: exact Prime Deals follow-up',
    'background:#123a73!important;background-color:#123a73!important',
    '[class*=PrioritizedInformationBar-module__container_],[class*=RefinementBar-module__refinementBarContainer_]',
    '[class*=_hve-rankable-banner_style_bannerImage_]',
    'v7.576 VIEWPORT: Prime Deals temporary-tab refinement submenus are a bottom-sheet React surface',
    'body:has(.discounts-react-app-bottom-sheet)',
    '[class*=Footer-module__clearFilters_],[class*=Footer-module__showResults_]',
    '[class*=RangeSlider-module__innerRail_]{background:#2162a1!important;background-color:#2162a1!important;}',
    'v7.575 VIEWPORT: the current Interests contextual menu uses a different sheet owner',
    'body:has([class*=_bW9ia_contextual-menu-bottom-sheet_])',
    '#a-page:has(#interests-ai-sticky-div):has(#product-grid) .ai-watchlist-container'
):
    assert tok in menus, tok
with tempfile.NamedTemporaryFile(suffix='.js',mode='w') as f:
    f.write('const css = ' + repr(menus) + ';\n')
    f.flush()
    subprocess.run(['node','--check',f.name],check=True,capture_output=True)
for tok in (
    '#define AD_VERSION "v7.576-prime-deals-refinements-menus"',
    '#include "ADNewMenus7482.js.inc"',
):
    assert tok in tweak, tok
print('PASS: v7.576 themes the Prime Deals refinement bottom sheets while retaining the v7.575 deals/interests follow-up rules')

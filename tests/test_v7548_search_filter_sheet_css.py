from pathlib import Path
f=Path('src/ADNewMenus7482.js.inc').read_text()
assert 'search filter sheet follow-up' in f
assert 'body:has(#search) :is([class*=filter-sheet],[class*=FilterSheet],[class*=search-filter],[class*=refinement-sheet],[class*=facet-sheet],[class*=filter-view],[class*=filterView],[id*=filter-sheet],[id*=search-filter],[id*=refinement-sheet],[id*=facet-sheet])' in f
assert 'background:#303335!important;background-color:#303335!important;border:1px solid #747a7c!important' in f
assert 'border-right:1px solid #494d4d!important' in f
assert 'content:none!important;display:none!important;background:none!important;border:0!important;box-shadow:none!important;' in f
assert 'background:#000!important;background-color:#000!important;border:1px solid #747a7c!important;border-color:#747a7c!important;box-shadow:none!important;color:#fff!important;-webkit-text-fill-color:#fff!important;' in f

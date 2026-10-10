from pathlib import Path
R=Path(__file__).resolve().parents[1]
CSS=(R/'src/ADNewMenus7482.js.inc').read_text(); T=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.619~handoff-regression-repair' in C
assert 'modal: paint only; preserve Amazon-authored geometry and controls.' in CSS
start=CSS.index('modal: paint only; preserve Amazon-authored geometry and controls.')
start=CSS.rfind('/*',0,start)
modal=CSS[start:CSS.index('/* Interests modal captured paint:')]
for bad in ('_bW9ia_close-icon_2PTPP','_bW9ia_clear-btn_jWGqR','border:1px','border-radius','width:','height:','position:','margin:','padding:','outline-color','box-shadow'):
    assert bad not in modal,bad
assert ':is(.a-sheet-web,.a-sheet-content-container){background:#000!important;background-color:#000!important;}' in modal
assert '#textareaLabel{color:#fff!important;-webkit-text-fill-color:#fff!important;}' in modal
assert 'i.a-icon-close._bW9ia_close-icon_3w-DL{filter:brightness(0) invert(1)!important;' in modal
assert 'ADClassNameIs7183(v,"WKContentView")' in T and '@selector(textInputTraitsForWebView)' in T and 'ADDarkWebInputTraits7512' in T
for good in ('ui-probe.sh export full','ui-probe.sh arm','ui-probe.sh export viewport','skeleton-probe.sh arm transition','skeleton-probe.sh export','git push origin main'): assert good in CMD,good
print('PASS: v7.619 keeps modal geometry stock, themes only floor/header/top-X paint, and primes cached WebKit traits before first keyboard presentation')

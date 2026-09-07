from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[1]
s=(ROOT/'src/Tweak.xm').read_text()
rule='#sc-page-container form#activeCartViewForm .sc-list-item .swipe-button.swipe-right-button,#sc-page-container form#activeCartViewForm .sc-list-item .swipe-button.swipe-right-button>div{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}'
assert s.count(rule)==1
# Preserve the parallel Saved-for-later swipe rule from v7.294.
saved='#sc-page-container form#savedCartViewForm .sc-list-item .swipe-button.swipe-right-button,#sc-page-container form#savedCartViewForm .sc-list-item .swipe-button.swipe-right-button>div{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}'
assert s.count(saved)==1
# No generic swipe-button recolor was introduced.
assert '.swipe-button{color:#e8e6e3' not in s
print('v7.351 Cart Save-for-later text regression: PASS')

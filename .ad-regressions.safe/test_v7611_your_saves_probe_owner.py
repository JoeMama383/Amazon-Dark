"""v7.619: exact r8 Your Saves owner, neutral colors, no duplicate geometry."""
from pathlib import Path
import json, subprocess, tempfile
import tinycss2
from lxml import html
from cssselect2 import ElementWrapper, compile_selector_list

R=Path(__file__).resolve().parents[1]
s=(R/'src/Tweak.xm').read_text()
j=(R/'src/ADYourSaves7611.js').read_text()
i=(R/'src/ADYourSaves7611.js.inc').read_text()
assert ''.join(json.loads(line) for line in i.splitlines())==j
assert '#include "ADYourSaves7611.js.inc"' in s
assert 'base=[base stringByAppendingString:saves7611];' in s
assert s.index('base=[base stringByAppendingString:reviewSort7609];') < s.index('base=[base stringByAppendingString:saves7611];')
assert 'Version: 7.619~handoff-regression-repair' in (R/'layout/DEBIAN/control').read_text()
assert 'FULL_INTERRUPTED_BY_BACKGROUND' in (R/'src/ADUniversalUIProbe7362.inc').read_text()
assert 'armed-background-during-full' in (R/'src/ADUniversalUIProbe7362.inc').read_text()
css=j.split('s.textContent=`',1)[1].split('`;',1)[0]
media=j.split('if(__TAME__){s.textContent+=`',1)[1].split('`;}',1)[0]
rules=[r for r in tinycss2.parse_rule_list(css+'\n'+media,skip_comments=True,skip_whitespace=True) if r.type=='qualified-rule']
assert len(rules)>=17
for r in rules:
    declarations=tinycss2.parse_declaration_list(r.content,skip_comments=True,skip_whitespace=True)
    assert declarations and all(d.type=='declaration' and d.important for d in declarations),tinycss2.serialize(r.prelude)
for color in ('#000','#303335','#747a7c','#494d4d','#fff','#2162a1'):
    assert color in j,color
for name in ('lists-list-carousel-header-button-row','awl-list-items','lists-list-carousel-image','lists-saves-item-image','ys-filters-scroller','items-categories-all-yoursaves-button'):
    if name == 'items-categories-all-yoursaves-button':
        assert 'a-button-selected' in j
    else:
        assert name in j
# Minimal post-update DOM from supplied r8 viewport. All selectors must be
# non-operative on unrelated pages lacking the two required menu witnesses.
doc=html.fromstring('''<html><body>
<div class="a-container lists-carousel-container"><div id="lists-list-carousel-header-button-row" class="your-stuff-header-button-row"><h4 class="your-saves-h4">Lists and Registries</h4><a class="lists-list-carousel-create-button"><i class="a-icon"></i></a></div>
<div id="lists-list-carousel-container" class="a-carousel-container"><li class="lists-carousel-element"><div class="a-box"><div class="a-box-inner"><a class="lists-list-carousel-card"><div class="lists-list-carousel-card-text"><p>Shopping list</p></div><img class="lists-list-carousel-image"></a></div></div></li></div></div>
<div id="items-menu-header-button-row"><h4 class="your-saves-h4">All saves</h4></div>
<div id="ys-filters-scroller"><span class="a-button a-button-toggle"><span class="a-button-inner"><span class="a-button-text">Filters</span></span></span><span id="items-categories-all-yoursaves-button" class="a-button a-button-toggle a-button-selected"><span class="a-button-inner"><span class="a-button-text">All</span></span></span><span class="a-button a-button-toggle"><span class="a-button-inner"><span class="a-button-text">Deals</span></span></span></div>
<ul id="awl-list-items"><li class="awl-item-wrapper"><div class="lists-saves-item-image"><img></div><div class="lists-saves-item-title">Book</div><div class="lists-saves-item-price-delivery"><span class="a-price"><span class="a-price-whole">27</span></span><div class="a-color-secondary">Free delivery</div><a class="a-color-link">Saved in Shopping List</a><span class="prime">prime</span></div><div class="lists-saves-item-actions-wrapper"><span class="a-button"><span class="a-button-inner"><span class="a-button-text">Add to Cart</span></span></span></div></li></ul>
</body></html>''')
wr=list(ElementWrapper.from_html_root(doc).iter_subtree())
selectors=[tinycss2.serialize(r.prelude).strip() for r in rules]
for target in ('lists-carousel-container','lists-list-carousel-image','lists-saves-item-title','a-price-whole','a-button-selected'):
    el=next(e for e in doc.iter() if target in (e.get('class') or '').split())
    w=next(n for n in wr if n.etree_element is el)
    assert any(any(c.test(w) for c in compile_selector_list(sel)) for sel in selectors),target
# Without both witnesses, no CSS can recolor unrelated widgets.
neg=html.fromstring('<html><body><div id="lists-list-carousel-header-button-row"><span class="a-button a-button-toggle">Filter</span></div></body></html>')
neg_nodes=list(ElementWrapper.from_html_root(neg).iter_subtree())
assert not any(any(c.test(n) for c in compile_selector_list(sel)) for n in neg_nodes for sel in selectors)
for bad in ('MutationObserver','querySelectorAll','setTimeout','setInterval','requestAnimationFrame','scrollTo','border-radius:','border-width:','content:"','::before','::after','filter:grayscale','background-image:none'):
    assert bad not in j,bad
# Validate both injection variants, preserving preference-controlled raster taming.
with tempfile.TemporaryDirectory() as td:
    cpp=Path(td)/'include.cpp'
    cpp.write_text('#include <stdio.h>\nstatic const char data[]=\n#include "ADYourSaves7611.js.inc"\n;\nint main(){return sizeof(data)>100?0:1;}\n')
    subprocess.run(['c++','-std=gnu++98','-I',str(R/'src'),'-fsyntax-only',str(cpp)],check=True)
for enabled in (True,False):
    v=j.replace('__TAME__','true' if enabled else 'false').replace('__FACTOR__','0.58' if enabled else '1.0')
    subprocess.run(['node','--check','-'],input=v,text=True,check=True)
print('PASS v7.619: probe-exact Your Saves OLED + secondary text + selected blue + optional tame; independent FULL/VIEWPORT diagnostic; JS/C++98')

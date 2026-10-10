"""Regression for v7.587 exact medical bottom-sheet/auth logo follow-up."""
import json
from pathlib import Path
import tinycss2, cssselect2
from lxml import html

ROOT = Path(__file__).resolve().parents[1]
js = ''.join(json.loads(line) for line in (ROOT / 'src/ADNewMenus7482.js.inc').read_text().splitlines() if line.strip())
css = js.split('s.textContent=`', 1)[1].split('`;', 1)[0]
matcher = cssselect2.Matcher()
for rule in tinycss2.parse_stylesheet(css, skip_comments=True, skip_whitespace=True):
    if rule.type != 'qualified-rule':
        continue
    try:
        sels = cssselect2.compile_selector_list(tinycss2.serialize(rule.prelude))
    except cssselect2.SelectorError:
        continue
    ds = {d.lower_name: (tinycss2.serialize(d.value).strip(), d.important)
          for d in tinycss2.parse_declaration_list(rule.content) if d.type == 'declaration'}
    for sel in sels:
        matcher.add_selector(sel, ds)

doc = html.fromstring('''<html><body>
<div id="main-content" class="ap-lego">
  <a id="nav-link-health-ai-mobile"></a>
  <pui-bottom-sheet id="links-bottomsheet" class="pui-element mshop pui-block">
    <div id="pui-bottom-sheet-modal" class="bottom-sheet-modal mshop bottom-sheet-modal-disable-scrollbar">
      <div id="bottom-sheet-modal-content" class="bottom-sheet-modal-content-mshop bottom-sheet-modal-content-disable-scrollbar">
        <a id="mobile-kyanite-logo"><img id="links-logo" alt="Amazon One Medical"/></a>
        <pui-list-link-item id="sheet-item"><div class="pui-text black-color" id="sheet-text">Browse all health</div></pui-list-link-item>
      </div>
    </div>
  </pui-bottom-sheet>
  <pui-bottom-sheet id="glowModal" class="pui-element pui-block"><div id="zip-floor">zip</div></pui-bottom-sheet>
</div>
<div class="cvf-widget-container"><form id="verification-code-form"></form></div>
<div id="cvf-page-content"><div class="a-row" id="auth-logo-strip"><img id="auth-logo" alt="Amazon" src="amazon.svg"/></div></div>
</body></html>''')
wrap = cssselect2.ElementWrapper.from_html_root(doc)
nodes = {e.etree_element.get('id'): e for e in wrap.iter_subtree() if e.etree_element.get('id')}

def paint(node_id, prop, pseudo=None):
    wins = []
    for spec, order, ps, ds in matcher.match(nodes[node_id]):
        if ps != pseudo or prop not in ds:
            continue
        value, important = ds[prop]
        wins.append(((important, spec, order), value))
    return max(wins)[1] if wins else None

assert paint('pui-bottom-sheet-modal', 'background') == '#000'
assert paint('bottom-sheet-modal-content', 'background') == '#000'
assert paint('glowModal', 'background') == '#000'
assert paint('mobile-kyanite-logo', 'filter') == 'none' # invert its leaf only, never twice
assert paint('sheet-text', 'color') == '#fff'
assert paint('auth-logo-strip', 'background') == '#000'
assert paint('auth-logo', 'filter') == 'brightness(0) invert(1)'
print('PASS: v7.587 exact One Medical bottom-sheet floors/logo inversion, ZIP floor, and auth Amazon logo strip ownership present')

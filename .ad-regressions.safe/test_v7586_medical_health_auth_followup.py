"""Probe-shaped regression for v7.586 Health AI/auth follow-up fixes."""
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
        selectors = cssselect2.compile_selector_list(tinycss2.serialize(rule.prelude))
    except cssselect2.SelectorError:
        continue
    declarations = {
        d.lower_name: (tinycss2.serialize(d.value).strip(), d.important)
        for d in tinycss2.parse_declaration_list(rule.content)
        if d.type == 'declaration'
    }
    for sel in selectors:
        matcher.add_selector(sel, declarations)

doc = html.fromstring('''<html><body>
<div id="a-page">
  <div class="kyanite-nav-logo-img"></div>
  <div class="background-color-white" id="confirm-card">
    <button class="yellow-round-button" id="continue-btn"><span id="continue-text">Continue</span></button>
  </div>
</div>
<div id="main-content" class="ap-lego">
  <a id="nav-link-health-ai-mobile"></a>
  <svg id="hourglass"><path id="hourglass-path" fill="#0F1111"/></svg>
  <button class="yellow-round-button" id="get-started"><span id="get-started-text">Get started</span></button>
</div>
<div id="warblerApplicationRoot">
  <div class="k2eBglky" id="fade-host"></div>
  <button data-testid="wfe-send-message-btn" id="send"><span id="send-inner">go</span><svg><path id="send-path" fill="#0F1111"/></svg></button>
  <div class="O8hGCkXk" id="sleep-copy">Sleep and your health</div>
  <img id="sleep-image"/>
  <svg id="sleep-svg"><path id="sleep-svg-path" fill="#000"/></svg>
</div>
<div class="cvf-widget-container"><form id="verification-code-form"></form></div>
<div id="auth-footer"><div id="footer-copy">copy</div></div>
<div class="a-color-offset-background" id="auth-gray-box"><span id="gray-box-text">gray box</span></div>
<div class="a-expander-content" id="more-help"><span id="more-help-text">No longer have access</span><a class="a-link-normal" id="change-link">change your number</a></div>
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

assert paint('continue-btn', 'background') == '#000'
assert paint('continue-btn', 'border-color') == '#747a7c'
assert paint('continue-text', 'color') == '#fff'
assert paint('confirm-card', 'background-color') == '#000'
assert paint('hourglass-path', 'fill') == '#fff'
assert paint('get-started', 'background') == '#000'
assert paint('get-started', 'border-color') == '#747a7c'
assert paint('send', 'background') == '#303335'
assert paint('send', 'border') == '0'
assert paint('sleep-image', 'visibility') == 'visible'
assert paint('sleep-image', 'opacity') == '1'
assert paint('sleep-svg-path', 'fill') == '#fff'
assert paint('fade-host', 'background', 'before') == 'transparent'
assert paint('fade-host', 'opacity', 'before') == '0'
assert paint('fade-host', 'background', 'after') == 'transparent'
assert paint('fade-host', 'opacity', 'after') == '0'
assert paint('auth-footer', 'background') == '#000'
assert paint('auth-gray-box', 'background') == '#000'
assert paint('more-help-text', 'color') == '#fff'
assert paint('change-link', '-webkit-text-fill-color') == 'currentColor'
print('PASS: v7.586 colors Health AI send/control owners, visible glyphs/fade removal, auth footer/help copy, and One Medical continue button exact paint')

from pathlib import Path
import re, subprocess, tempfile
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
A=(ROOT/'src/ADSponsored.m').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.401~native-payment-sheets-completion' in C
assert '#define AD_VERSION "v7.401-native-payment-sheets-completion"' in S
block=A
# Reconstruct adjacent Objective-C string literals and parse the injected JS.
lits=re.findall(r'@"((?:\\.|[^"\\])*)"', block)
assert lits
js=''.join(bytes(x,'utf-8').decode('unicode_escape') for x in lits)
assert "ad7384-killer" in js
assert js.count('{display:none!important') == 33  # all 86 selectors checked separately in v7.388 semantic test
# No selector may contain nested :has(); that is invalid Selectors Level 4 syntax.
css_literal=re.search(r's\.textContent=("(?:\\.|[^"\\])*")', js)
assert css_literal, 'missing CSS literal'
import json
css=json.loads(css_literal.group(1))
for rule in [x for x in css.splitlines() if x.strip()]:
    sel=rule.split('{',1)[0]
    assert sel.count(':has(') <= 1, sel
# Critical current AmznKiller families omitted by the first partial port are present.
for token in [
    'sp-mobile-thematic-bundle', 'sb-themed-collection', '-mobile_loom-mobile-inline-slot',
    'MAIN-FEATURED_ASINS_LIST-', 'MAIN-VIDEO_SINGLE_PRODUCT-', '_adFeedbackWrapper_',
    'loom-mobile-top-slot_hsa-id-', 'loom-mobile-brand-footer-slot_hsa-id-',
    'puis-sponsored-label-text', 'sponsored_label_tap_space', 'data-component-type^="aspa-asin-ajax"',
]:
    assert token in css, token
# Probe-confirmed Home blank slot can collapse, but only when its immediate widget is itself an ad.
assert '#gwm-dashboard>li.gwm-tile:has(>span.a-list-item>div[class*="mobile-gateway-atf_ad-"])' in css
assert "li[class*='_hp-mosaic-container_style_widgetContainer']:has" not in css
# Explicit true-only sponsored carousel match.
assert 'data-a-carousel-options*=\'"isSponsoredProduct":"true"\'' in css
# JS syntax itself must remain valid.
with tempfile.NamedTemporaryFile('w',suffix='.js',delete=False) as f:
    f.write(js); name=f.name
cp=subprocess.run(['node','--check',name],capture_output=True,text=True)
assert cp.returncode==0, cp.stderr
for bad in ['MutationObserver','setInterval(','setTimeout(','requestAnimationFrame(']:
    assert bad not in js, bad
print('PASS: v7.388 sponsored blocker uses isolated valid rules with full selector-family coverage')

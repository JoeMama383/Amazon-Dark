from pathlib import Path
import re, json
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
A=(ROOT/'src/ADSponsored.m').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()

assert 'Version: 7.412~address-location-aux-theme' in C
assert '#define AD_VERSION "v7.412-address-location-aux-theme"' in S
block=A
lits=re.findall(r'@"((?:\\.|[^"\\])*)"', block)
js=''.join(bytes(x,'utf-8').decode('unicode_escape') for x in lits)
m=re.search(r's\.textContent=("(?:\\.|[^"\\])*")', js)
assert m
css=json.loads(m.group(1))

# Preserve the v7.382 precision correction: only explicit true is blocked.
assert 'data-a-carousel-options*=\'"isSponsoredProduct":"true"\'' in css
assert 'data-a-carousel-options*="isSponsoredProduct"' not in css

# The v7.381 mixed-carousel regression must not return: no Home mosaic owner is
# selected simply because any arbitrary sponsored descendant exists.
assert "li[class*='_hp-mosaic-container_style_widgetContainer']:has" not in css
assert '#gwm-dashboard>li.gwm-tile:has(:is(' not in css

# Window ownership remains the narrow upstream single-creative/video semantics.
assert 'li.gwm-window-tile:has(div[data-csa-c-painter="single-creative-card"] [data-ad-feedback-label-id])' in css
assert 'li.gwm-window-tile:has(div[data-csa-c-painter="single-video-card"] [data-ad-feedback-label-id])' in css

# v7.388 must not reintroduce illegal nested :has() syntax.
for rule in [x for x in css.splitlines() if x.strip()]:
    sel=rule.split('{',1)[0]
    assert sel.count(':has(') <= 1, sel

for bad in ['MutationObserver','setInterval(','setTimeout(','requestAnimationFrame(']:
    assert bad not in js, bad
assert 'ADSharedUserScript7387(1,ADKillerSponsoredJS7384,NO,NO)' in S and 'injectionTime:WKUserScriptInjectionTimeAtDocumentStart' in S
print('PASS: v7.382 precision contracts survive v7.388 without nested :has or broad carousel promotion')

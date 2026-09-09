from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()

assert 'Version: 7.382~sponsored-carousel-precision' in C
assert '#define AD_VERSION "v7.382-sponsored-carousel-precision"' in S
start=S.index('static NSString *ADKillerSponsoredJS7382(void)')
end=S.index('static NSString *ADPriceHistoryJS7380', start)
k=S[start:end]

# Critical upstream-aligned precision fix: a carousel merely exposing the option
# key must not be blocked. The value has to be explicitly true.
assert "[data-a-carousel-options*='\\\\\\\"isSponsoredProduct\\\\\\\":\\\\\\\"true\\\\\\\"']" in k
assert 'data-a-carousel-options*=\\\"isSponsoredProduct\\\"' not in k
assert "[data-a-carousel-options*='isSponsoredProduct']" not in k

# Dashboard shell collapse is allowed only when the *immediate widget root* is
# an explicit ad placement. Nested ad labels inside a normal recommendation card
# cannot promote to the entire li.gwm-tile.
assert '#gwm-dashboard>li.gwm-tile:has(>span.a-list-item>:is(' in k
assert "[class*='mobile-gateway-atf_ad-']" in k
assert '#gwm-dashboard>li.gwm-tile:has(:is(' not in k

# Window ownership mirrors the narrow AmznKiller selector semantics: only a
# single-creative/video card with the feedback label can collapse its window tile.
assert "#gwm-window>li.gwm-window-tile:has(div[data-csa-c-painter='single-creative-card'] [data-ad-feedback-label-id])" in k
assert "#gwm-window>li.gwm-window-tile:has(div[data-csa-c-painter='single-video-card'] [data-ad-feedback-label-id])" in k
assert '#gwm-window>li.gwm-window-tile:has(:is(' not in k

# A Home mosaic owner may collapse only when its direct child is itself an
# explicit ad root. A sponsored descendant deeper in a mixed card is insufficient.
assert "li[class*='_hp-mosaic-container_style_widgetContainer']:has(>:is(" in k
assert "li[class*='_hp-mosaic-container_style_widgetContainer']:has(:is(" not in k

# Keep individual sponsored-card removal and common high-confidence ad families.
for token in [
    '.a-carousel-card:has(.p13n-sc-sponsored-label)',
    '.s-result-item.AdHolder',
    '.s-result-item:has([data-ad-feedback-label-id])',
    '.dp-widget-card-deck:has([data-ad-placement-metadata])',
    "div[data-csa-c-painter='single-creative-card']:has([data-ad-feedback-label-id])",
    "div[data-csa-c-painter='single-video-card']:has([data-ad-feedback-label-id])",
    '[data-ad-id]',
    "div[data-cel-widget^='mobile-ads-']",
]:
    assert token in k, token

# Still a declarative document-start style injection: no recurring work.
for bad in ['MutationObserver','setInterval(','setTimeout(','requestAnimationFrame(',"addEventListener('scroll'",'addEventListener("scroll"']:
    assert bad not in k, bad
assert 'ADKillerSponsoredJS7382() injectionTime:WKUserScriptInjectionTimeAtDocumentStart' in S


H=(ROOT/'scripts/skeleton-probe.sh').read_text()
for prev in ['v7.381-probe-status.json','v7.380-probe-status.json','v7.379-probe-status.json']:
    assert prev in H
assert '|379|380|381|382)-' in H

print('PASS: v7.382 sponsored filtering preserves mixed carousels and collapses only exact/direct ad owners')

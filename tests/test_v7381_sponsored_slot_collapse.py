from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()

assert 'Version: 7.381~sponsored-slot-collapse-ad-floor' in C
assert '#define AD_VERSION "v7.381-sponsored-slot-collapse-ad-floor"' in S

# The white transition owner is the dashboard list-item shell itself. Keep the
# accepted ADFloorJS payload unchanged and add one tiny floor to the existing
# immutable document-start core program rather than a separate WKUserScript.
floor=S[S.index('static NSString *ADHomeAdShellFloorJS7381(void)'):S.index('// v7.381: retain the independently implemented AmznKiller-inspired optional features.')]
assert '#gwm-dashboard>li.gwm-tile{background:#000!important;background-color:#000!important;}' in floor
assert 'ADFloorJS(),ADHomeAdShellFloorJS7381()' in S
assert 'stringWithFormat:@"%@%@%@%@%@"' in S

# Block mode must collapse the owning layout slots, not merely blank inner ads.
start=S.index('static NSString *ADKillerSponsoredJS7381(void)')
end=S.index('static NSString *ADPriceHistoryJS7380', start)
killer=S[start:end]
for token in [
    '#gwm-dashboard>li.gwm-tile:has(:is(',
    '#gwm-window>li.gwm-window-tile:has(:is(',
    "li[class*='_hp-mosaic-container_style_widgetContainer']:has(:is(",
    "[class*='mobile-gateway-atf_ad-']",
    '[data-ad-id]',
    '[data-ad-feedback-label-id]',
    "[data-cel-widget^='mobile-ads-']",
    "[cel_widget_id^='adplacements:']",
    'display:none!important',
    'flex:0 0 0!important',
    'min-width:0!important',
    'min-height:0!important',
]:
    assert token in killer, token

# A normal Home mosaic card can carry an empty sponsored-badge placeholder;
# never promote a generic 'sponsored' class substring to outer-slot proof.
assert ":has(:is([class*='sponsored']" not in killer.lower()
assert "[class*='asin-sponsored']" not in killer.lower()

# Remain declarative and document-start only.
for bad in ['MutationObserver','setInterval(','setTimeout(','requestAnimationFrame(','addEventListener(\'scroll\'','addEventListener("scroll"']:
    assert bad not in killer, bad
assert 'ADKillerSponsoredJS7381() injectionTime:WKUserScriptInjectionTimeAtDocumentStart' in S

# Preserve price history: one Keepa insertion and one Camel insertion only.
price=S[S.index('static NSString *ADPriceHistoryJS7380'):S.index('// One immutable document-start program')]
assert price.count("chart('Keepa'")==1
assert price.count("chart('CamelCamelCamel'")==1

print('PASS: v7.381 collapses positive sponsored owner slots and owns Home ad first-paint floor without recurring work')

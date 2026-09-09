from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()

assert 'Version: 7.382~sponsored-carousel-precision' in C
assert '#define AD_VERSION "v7.382-sponsored-carousel-precision"' in S

# Preserve the successful v7.381 first-paint repair: the Home dashboard shell
# itself owns the stock white loading floor, and that floor remains OLED at
# document start even when sponsored blocking is disabled.
floor=S[S.index('static NSString *ADHomeAdShellFloorJS7381(void)'):S.index('// v7.382: AmznKiller-inspired sponsored filtering')]
assert '#gwm-dashboard>li.gwm-tile{background:#000!important;background-color:#000!important;}' in floor
assert 'ADFloorJS(),ADHomeAdShellFloorJS7381()' in S

# v7.382 intentionally removes the v7.381 broad ancestor promotion that could
# erase an entire mixed carousel when only one descendant was sponsored.
start=S.index('static NSString *ADKillerSponsoredJS7382(void)')
end=S.index('static NSString *ADPriceHistoryJS7380', start)
k=S[start:end]
assert '#gwm-dashboard>li.gwm-tile:has(:is(' not in k
assert '#gwm-window>li.gwm-window-tile:has(:is(' not in k
assert "li[class*='_hp-mosaic-container_style_widgetContainer']:has(:is(" not in k

print('PASS: v7.382 OLED ad loading floor retained; broad outer-slot sponsored promotion removed')

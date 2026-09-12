from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
A=(ROOT/'src/ADSponsored.m').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()

assert 'Version: 7.416~location-canonical-owner' in C
assert '#define AD_VERSION "v7.416-location-canonical-owner"' in S

# Preserve the successful v7.381 first-paint repair: the Home dashboard shell
# itself owns the stock white loading floor, and that floor remains OLED at
# document start even when sponsored blocking is disabled.
floor=S[S.index('static NSString *ADHomeAdShellFloorJS7381(void)'):S.index('// v7.388: Sponsored-content filtering follows AmznKiller')]
assert '#gwm-dashboard>li.gwm-tile{background:#000!important;background-color:#000!important;}' in floor
assert 'ADFloorJS(),ADHomeAdShellFloorJS7381()' in S

# v7.388 intentionally removes the v7.381 broad ancestor promotion that could
# erase an entire mixed carousel when only one descendant was sponsored.
k=A
assert '#gwm-dashboard>li.gwm-tile:has(:is(' not in k
assert "li[class*='_hp-mosaic-container_style_widgetContainer']:has" not in k

print('PASS: v7.388 OLED ad loading floor retained; broad outer-slot sponsored promotion removed')

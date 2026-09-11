from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.410~permission-text-location-firstpaint' in C
assert '#define AD_VERSION "v7.410-permission-text-location-firstpaint"' in S
block=S.split('// v7.393 FULL r2/r3/r4 (16:59, 17:08, 17:09), corrected by v7.398:',1)[1].split('// v7.390 FULL r2: Subscribe & Save loading transition.',1)[0]

# Returns and Refunds: descendant article ownership covers direct or OAS-wrapped content.
assert '.cs-help-v4 .cs-help-content article.help-content' in block
assert '.cs-help-landing-section div.a-box' in block
assert '.cs-help-landing-section div.a-box>.a-box-inner' in block
assert '.cs-help-landing-section .a-box-list>li{border-color:#747a7c!important;}' in block
assert '.cs-help-landing-section a.a-touch-link' in block
assert '.cs-help-landing-section i.a-icon-touch-link' in block
assert 'filter:brightness(0) invert(1)!important' in block
assert 'article.help-content p.lead,' in block
assert 'article.help-content .cs-help-landing-section{border-bottom-color:#000!important;}' in block

# Consumer Use Tax: exact table/cell family owns floor, white neutral text and gray borders.
assert 'article.help-content table.a-bordered' in block
assert 'table.a-bordered :is(thead,tbody,tr)' in block
assert 'table.a-bordered :is(th,td)' in block
assert 'background:#000!important' in block
assert 'border-color:#747a7c!important' in block
assert 'color:#fff!important' in block
# Authored blue links and explicit gray text families remain dynamic/authored.
assert 'table.a-bordered a *{-webkit-text-fill-color:currentColor!important;}' in block
assert '.a-color-secondary' in block and '.a-color-tertiary' in block

# Help submenus were pre-mounted as white AUI vertical cards; all submenu indices share one stable class family.
assert "h1[class*='help-content-submenu']" in block
assert "[class*='help-content-submenu'].a-section .a-box.a-vertical" in block
assert "[class*='help-content-submenu'].a-section .a-box-list>li{border-color:#747a7c!important;}" in block
assert "[class*='help-content-submenu'].a-section i.a-icon-touch-link" in block

# Instructional image frame is darkened without applying a filter to the authored figure raster.
fig=block.split('// v7.398 FULL r6:',1)[1]
assert '.cs-help-content-frame .a-box.a-first' in fig
assert 'filter:' not in fig
print('PASS: v7.398 covers Returns/Tax wrapped articles, every help submenu card, and instructional figure shell while preserving dynamic text/media')

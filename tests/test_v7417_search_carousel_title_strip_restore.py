from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text(); C=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.455~pdp-manual-full' in C
assert '#define AD_VERSION "v7.455-pdp-manual-full"' in S
# v7.417 repair retained in v7.418: keep exact old text owner and add narrow structural fallbacks.
assert '.cards_carousel_widget-sug-container-top .cards_carousel_widget-sug-text{background:#000!important' in S
for token in [
    '.cards_carousel_widget-sug-column>:is(img,picture,[class*=cards_carousel_widget-sug-im])+*:not(:has(img,picture,source,[class*=cards_carousel_widget-sug-im]))',
    '.cards_carousel_widget-sug-column>:has(>:is(img,picture,source,[class*=cards_carousel_widget-sug-im]))+*:not(:has(img,picture,source,[class*=cards_carousel_widget-sug-im]))',
    '.cards_carousel_widget-sug-column>*:last-child:not(:has(img,picture,source,[class*=cards_carousel_widget-sug-im]))',
    'border-color:#494d4d!important'
]: assert token in S,token
# Do not restore the v7.353 broad descendant floor owner that previously risked image regressions.
assert '.cards_carousel_widget-sug-container-top [class*=cards_carousel_widget-sug-]:not(img):not(picture):not(source)' not in S
assert '.cards_carousel_widget-sug-container-top img{filter:brightness(var(--ad7-cards-twb)) saturate(1)!important' in S
print('PASS: v7.418 retains v7.417 narrow non-media Search carousel title-strip restoration')

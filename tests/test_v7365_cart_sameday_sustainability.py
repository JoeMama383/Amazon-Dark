from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
t=(ROOT/'src/Tweak.xm').read_text()
ctl=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.409~permission-controls-location-rails-fix' in ctl
assert '#define AD_VERSION "v7.409-permission-controls-location-rails-fix"' in t

# Probe-backed p13n same-day meter: repaint only the stock-white underlying track.
assert '#sc-page-container .p13n-same-day-progress-container .a-meter.p13n-same-day-bar-v2{background:#000!important' in t
meter=t.split('#sc-page-container .p13n-same-day-progress-container .a-meter.p13n-same-day-bar-v2{',1)[1].split('}',1)[0]
assert '.a-meter-bar' not in meter
assert 'rgb(11,123,60)' not in meter
# Exact neutral sentence/price lanes from the FULL probe become light.
for token in ['.p13n-same-day-info-text-before-price','.p13n-same-day-info-text-after-price','.p13n-same-day-amount-left-v2','.p13n-same-day-threshold-price-v2']:
    assert token in t
assert '#sc-saved-cart .sc-list-item .sc-nested-list .a-section.a-spacing-none>.a-size-small' in t

# Empty/removed Cart copy is light while the product title stays Amazon blue.
assert '#sc-page-container #sc-active-cart .sc-cart-header' in t
assert '#sc-page-container .sc-list-item-removed-msg .sc-undo-slide-content' in t
assert '#sc-page-container .sc-list-item-removed-msg .sc-removed-msg-title' in t
assert 'color:rgb(33,98,161)!important;-webkit-text-fill-color:rgb(33,98,161)!important' in t

# Product-scroll Sustainability sheet exact family: OLED floors + standard card border.
assert 'body:has(#search) .a-sheet-web:has(.s-pc-container-bottom-sheet)' in t
assert '.s-pc-bottom-sheet-carousel-inner{background:#000!important' in t
assert 'border:1px solid #494d4d!important' in t
assert '.s-pc-sticky-footer' in t
assert '.s-pc-container-bottom-sheet-heading' in t
# Neutral copy is light; authored program/link accents remain explicit and images are not broadly filtered here.
assert '.s-pc-sticky-footer .s-pc-program-name .a-color-base{color:#e8e6e3!important' in t
assert '.s-pc-sticky-footer .s-pc-program-name .a-color-link{color:rgb(33,98,161)!important' in t
assert '.s-pc-program-name{color:rgb(4,112,91)!important' in t
new=t.split('// v7.365 probe-backed Sustainability sheet.',1)[1].split('#search .s-widget-container:has(.s-trft)',1)[0]
assert 'filter:' not in new and '-webkit-filter:' not in new

# Keep production runtime event-driven.
assert 'MutationObserver(' not in t
assert 'setInterval(' not in t
assert 'requestAnimationFrame(' not in t
print('PASS: v7.365 exact Cart same-day/removed/meta and Sustainability-sheet ownership present')

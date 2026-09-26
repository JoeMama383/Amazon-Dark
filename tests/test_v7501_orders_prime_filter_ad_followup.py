from pathlib import Path
import json
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text()
J=''.join(json.loads(line) for line in (R/'src/ADNewMenus7482.js.inc').read_text().splitlines() if line.strip())
C=(R/'layout/DEBIAN/control').read_text()
CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.501~orders-prime-filter-ad-followup' in C
assert '#define AD_VERSION "v7.501-orders-prime-filter-ad-followup"' in T
assert 'AmazonDark-v7.501-orders-prime-filter-ad-followup-source.zip' in CMD
root='section.your-orders-mobile-content-container.aok-relative.js-yo-container'
assert root+' [class*=\"_timely-reminders-information-tile_style_tileContainer\"]::before{' in J
for tok in ('content:none!important;','display:none!important;','background:none!important;','background-color:inherit!important;'):
    assert tok in J, tok
assert root+' .search-bar__open-filter-link{' in J
for tok in ('border:1px solid #747a7c!important;','border-radius:20px!important;','-webkit-tap-highlight-color:transparent!important;'):
    assert tok in J, tok
for tok in ('[data-focus-visible-added]','.a-button-focus','.search-bar__open-filter-link .a-button::before','.search-bar__open-filter-link .a-box-inner::after'):
    assert tok in J, tok
assert 'static NSString *ADPDPAdImageBackgroundJS7501(void)' in T
for tok in ('ad7501-pdp-ad-image-bg','#sponsoredProducts_feature_div','_c2ItY_asinImageWrapper_','_p13n-mobile-sims-fbt_fbt-mobile_image-background_','stringByAppendingString:ADPDPAdImageBackgroundJS7501()]'):
    assert tok in T, tok
for bad in ('MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in J, bad
print('PASS: v7.501 normalizes Prime card surfaces, suppresses the sticky Orders filter focus border, and blacks out PDP ad image canvases')

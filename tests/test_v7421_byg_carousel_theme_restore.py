from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text(); C=(ROOT/'layout/DEBIAN/control').read_text()
UI=(ROOT/'scripts/ui-probe.sh').read_text(); SK=(ROOT/'scripts/skeleton-probe.sh').read_text()
INC=(ROOT/'src/ADUniversalUIProbe7362.inc').read_text(); JS=(ROOT/'src/ADUniversalUIProbe7362.js.inc').read_text()
F=json.loads((ROOT/'tests/fixtures/v7421-byg-carousel-theme-restore.json').read_text())
assert 'Version: 7.443~user-style-ad-ownership-validation-fix' in C
assert '#define AD_VERSION "v7.443-user-style-ad-ownership-validation-fix"' in S
# Probe evidence for the alternate BYG renderer.
assert 'speed-byg-sf-mobile-carousel_style_carouselContainer' in F['carousel_class']
assert F['carousel_background']=='rgb(255, 255, 255)'
assert F['atc_name']=='submit.addToCart' and F['atc_background']=='rgb(255, 216, 20)' and F['atc_rect']=='32x32'
# Own the exact alternate carousel shell without broadening every checkout descendant.
assert '[class*=_speed-byg-sf-mobile-carousel_style_carouselContainer_]' in S
# Use stable semantic ATC ownership so old dense-grid and new speed-carousel both theme.
sel="#checkoutDisplayPage .checkout-byg-mobile-container button[name='submit.addToCart']"
assert sel in S
blk=S.split(sel,1)[1].split('}"',1)[0]
for tok in ['background:#303335!important','border:1px solid #747a7c!important','outline:none!important']:
    assert tok in blk,tok
assert "button[name='submit.addToCart'] .a-icon-small-add{filter:brightness(0) invert(1)!important" in S
# Pressed state remains dark.
assert "button[name='submit.addToCart']:is(:focus,:focus-visible,:active){background:#202324!important" in S
# Steppers now key from the stable BYG owner rather than the old dense-grid wrapper only.
assert '#checkoutDisplayPage .checkout-byg-mobile-container .a-stepper-inner-container{background:#303335!important' in S
# Old dense-grid image-overlay exception remains to avoid cuts through product images.
assert '[class*=_denseGridAxSpotAtcOverlay_]' in S
# No new recurring mechanism.
delta=S.split('static NSString *ADCheckoutFloorJS7369(void){',1)[1].split('static NSString *ADCheckoutTWBJS7369',1)[0]
for bad in ('new MutationObserver(', 'setInterval(', 'requestAnimationFrame('): assert bad not in delta,bad
# Probe identities current.
assert 'VER=7.443' in UI and 'AD_PROBE_VERSION=7.443' in SK and 'AD_PROBE_NAME=AmazonDark-v7.443' in SK
assert 'AMAZONDARK v7.443 UNIVERSAL' in INC and 'AmazonDark-v7.443-ui-viewport.arm' in INC and "version:'7.443'" in JS
assert 'in 7.443~*)' in SK and 'Install the v7.443 Actions package first.' in SK
print('PASS: current build retains the speed-BYG carousel shell and semantic gray/white add-to-cart controls while retaining the old dense-grid path')

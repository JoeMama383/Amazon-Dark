from pathlib import Path
import re, subprocess, tempfile
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
UI=(ROOT/'scripts/ui-probe.sh').read_text(); SK=(ROOT/'scripts/skeleton-probe.sh').read_text()
assert 'Version: 7.455~pdp-manual-full' in C
assert '#define AD_VERSION "v7.455-pdp-manual-full"' in S
assert 'VER=7.455' in UI and 'AD_PROBE_VERSION=7.455' in SK and 'AD_PROBE_NAME=AmazonDark-v7.455' in SK

pdp=S[S.index('static NSString *ADPDPCompletionJS7405'):S.index('static NSString *ADPDPCompletionTWBJS7405')]
twb=S[S.index('static NSString *ADPDPCompletionTWBJS7405'):S.index('// v7.432: PDP APE/SafeFrame', S.index('static NSString *ADPDPCompletionTWBJS7405'))]
sf=S[S.index('static NSString *ADPDPSafeFrameJS7432'):S.index('// v7.412 FULL r1', S.index('static NSString *ADPDPSafeFrameJS7432'))]

# r2: exact main-document APE lightAds carousel from the 23:12 probe.
for tok in [
    '#ape_detail_mobile-app-detail-ilm_mshop_placement[class~=\\"text/x-APE-lightAds\\"]',
    '[data-csa-c-painter=\\"sb-collections-ilm-mobile\\"]',
    '[class*=_c2ItY_cardWrapper_]',
    '[class*=_c2ItY_container_]',
    '[class*=_c2ItY_containerInner_]',
    '[class*=_c2ItY_asinImage_]',
    'border:1px solid #494d4d!important',
    'background:#000!important',
]: assert tok in pdp,tok
# Neutral price/copy is light; semantic lanes are explicitly preserved.
for tok in ['.a-price-whole','.a-price-symbol','.a-price-fraction','.a-color-link','.a-color-price','[class*=prime]','[class*=star]','[class*=rating]']:
    assert tok in pdp,tok
# The exact live ILM product raster is routed into the configurable white tamer.
assert '[data-csa-c-painter=sb-collections-ilm-mobile] img[class*=_c2ItY_asinImage_]' in twb
assert 'filter:brightness(%.3f)!important' in twb
assert 'mix-blend-mode:normal!important' in twb

# r1/r3: exact main-frame APE owners include the current middle/btf IDs and hero video IDs.
for tok in [
    '#mobile-ads-middle-app-dramabot_feature_div',
    '#ape_detail_btf_mshop_wrapper',
    '#ape_detail_btf_mshop_iframe',
    '#universal-hero-quick-promo_feature_div',
    '#ape_detail_mobile-hero-quick-promo_mshop_wrapper',
    '#ape_detail_mobile-hero-quick-promo_mshop_iframe',
]: assert tok in pdp,tok

# Child SafeFrame treatment dynamically activates on all currently observed renderer signatures.
for tok in ['#dynamic-bb','[data-testid=gridContainer]','[data-acei-id=prod-img]','[data-testid=product-description]','[data-testid=brand-product-description]','[data-testid*=product-image]']:
    assert tok in sf,tok
# OLED floors, neutral text, existing border recolor, semantic preservation, and raster taming are all present.
for tok in [
    'background:#000!important',  # shorthand owns the same OLED fill
    'border-color:#494d4d!important',
    'color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important',
    '[data-testid=formatted-price]',
    '.a-color-link', '.a-color-price', '[class*=prime]', '[class*=star]', '[class*=rating]',
    'filter:brightness(%.3f)!important',
    'mix-blend-mode:normal!important',
]: assert tok in sf,tok
# No new recurring runtime machinery.
for bad in ('MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in sf,bad

# Emitted SafeFrame JavaScript must still parse. Replace format placeholders with a valid scalar first.
lits=re.findall(r'@?"((?:\\.|[^"\\])*)"', sf)
js=''.join(bytes(x,'utf-8').decode('unicode_escape') for x in lits).replace('%.3f','0.684').replace('%%','%')
with tempfile.NamedTemporaryFile('w',suffix='.js',delete=False) as f:
    f.write(js); path=f.name
r=subprocess.run(['node','--check',path],text=True,capture_output=True)
Path(path).unlink(missing_ok=True)
assert r.returncode==0,r.stderr
print('PASS: v7.437 standardizes all three probe-confirmed PDP standalone ad renderer families')

from pathlib import Path
import subprocess,tempfile
from payload_source import block,payload

T=(Path(__file__).resolve().parents[1]/'src/Tweak.xm').read_text()
frag=payload(T,'ADDealsPriceHistoryFollowupJS7574')
for tok in (
    '#ad7380-price-history img{filter:invert(1) hue-rotate(180deg) brightness(.88)!important',
    '.discounts-react-app,.deals-page-container-mobile,.alm-storefront-container-mobile-zones',
    'dps-slot-adapter',
    'ape-placement',
    "background-color','#123a73'",
    "background-color','#5f5331'",
    'data-ad7574-tamed',
    "filter','brightness(0.68)'",
    'background:#494d4d!important;border-color:#494d4d!important;background-image:none!important;box-shadow:none!important;'
):
    assert tok in frag, tok
with tempfile.NamedTemporaryFile(suffix='.js',mode='w') as f:
    f.write(frag)
    f.flush()
    subprocess.run(['node','--check',f.name],check=True,capture_output=True)
assert "base=[base stringByAppendingString:ADDealsPriceHistoryFollowupJS7574()];" in T
print('PASS: v7.574 inverts price-history charts and performs one-shot deals-page blue/gold taming, divider gray normalization, compact ad border gray, and small media toning without recurring observers')

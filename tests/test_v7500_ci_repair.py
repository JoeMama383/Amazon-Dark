from pathlib import Path
import json, hashlib
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text()
J=''.join(json.loads(line) for line in (R/'src/ADNewMenus7482.js.inc').read_text().splitlines() if line.strip())
C=(R/'layout/DEBIAN/control').read_text()
UI=(R/'scripts/ui-probe.sh').read_text()
SK=(R/'scripts/skeleton-probe.sh').read_text()
V=(R/'scripts/validate.sh').read_text()
CMD=(R/'COMMANDS.md').read_text()
W=(R/'.github/workflows/build.yml').read_text()
assert 'Version: 7.500~orders-prime-media-divider-ci-repair' in C
assert '#define AD_VERSION "v7.500-orders-prime-media-divider-ci-repair"' in T
assert 'VER=7.500' in UI
assert 'AD_PROBE_VERSION=7.500' in SK
assert 'AD_PROBE_NAME=AmazonDark-v7.500' in SK
assert 'tests/test_v7499_orders_prime_media_divider.py' in V
assert 'AD_STRICT_VALIDATE=0 sh scripts/validate.sh' in CMD
assert 'AmazonDark-v7.500-orders-prime-media-divider-ci-repair-source.zip' in CMD
for tok in ('actions/checkout@v7','actions/setup-python@v7','actions/upload-artifact@v7','AD_STRICT_VALIDATE=1 sh scripts/validate.sh'):
    assert tok in W, tok
root='section.your-orders-mobile-content-container.aok-relative.js-yo-container'
# Retain v7.499 UI fixes.
assert root+' [class*="_timely-reminders-information-tile_style_tileContainer"]::before{' in J
assert root+' [class*="_timely-reminders-information-tile_style_imageContainer"]::after{' in J
assert "background:rgba(0,0,0,.58)!important;" in J
assert root+' form.search-bar.js-search-bar::after{' in J
assert 'left:0!important;right:0!important;bottom:0!important;height:1px!important;background:#494d4d!important;' in J
assert root+' .search-bar__open-filter-link-container.js-open-filter-link-container::before{' in J
assert 'top:4px!important;bottom:6px!important;width:1px!important;background:#747a7c!important;' in J
qty=root+' .product-image__qty{'
assert qty in J
for tok in ('display:grid!important;','place-items:center!important;','width:20px!important;','height:20px!important;','padding:0 0 2px 0!important;'):
    assert tok in J, tok
# Probe behavior stays frozen; only version strings may differ.
expected={'scripts/ui-probe.sh': '0fba3a4f81c9ef610e73c2e1a64a819be0dbc405c54f27d9f4bb8e93665d740a', 'scripts/skeleton-probe.sh': 'edb24377fffad68c853c88a66d794cf0853c2a4ed530e8fe6765acc52d62badb', 'src/ADUniversalUIProbe7362.inc': '9042c7c1252b17fd419b414eae3be96f09a5596df969f7d8b3be29ea492c058b', 'src/ADUniversalUIProbe7362.js.inc': 'e64f2369db489ba0584c944db2f90eed2dcc933c6fc0a561e2a891449d2b285a', 'src/ADUniversalUIProbe7362.frame.js.inc': '2c289dd38d6849130e9a1fa22fd216400964ab0785f8af7fa0aebf2b12cc1bb8', 'src/ADUIProbeViewportSample7449.js.inc': 'f78fcfcbba257e284eff71020c9d5cd7b2508c971a83dc4fcdb3636262c8eb8c', 'src/ADPDPMainStream7451.js.inc': 'f5a4903a04797f83c25346c9da2ff67003a83363cffcb9ab6fbdf2ee31635688', 'src/ADUIProbeScroll7446.js.inc': 'fbb2c8171e1c4a11065b7fdfcfa42abfdcf2161d2d8d97d21128f349065f7840'}
for rel,h in expected.items():
    s=(R/rel).read_text().replace('7.500','7.CUR')
    assert hashlib.sha256(s.encode()).hexdigest()==h, rel
for bad in ('MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in J, bad
print('PASS: v7.500 repairs the v7.499 CI regression, removes Node20 Actions warnings, retains Orders UI fixes, and preserves probe behavior')

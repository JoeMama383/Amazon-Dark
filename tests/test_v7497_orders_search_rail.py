from pathlib import Path
import json, hashlib
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text()
J=''.join(json.loads(line) for line in (R/'src/ADNewMenus7482.js.inc').read_text().splitlines() if line.strip())
C=(R/'layout/DEBIAN/control').read_text()
UI=(R/'scripts/ui-probe.sh').read_text()
SK=(R/'scripts/skeleton-probe.sh').read_text()
V=(R/'scripts/validate.sh').read_text()

assert 'Version: 7.497~orders-search-rail' in C
assert '#define AD_VERSION "v7.497-orders-search-rail"' in T
assert 'VER=7.497' in UI
assert 'AD_PROBE_VERSION=7.497' in SK
assert 'AD_PROBE_NAME=AmazonDark-v7.497' in SK
assert 'tests/test_v7496_orders_owner_correction.py' in V
root='section.your-orders-mobile-content-container.aok-relative.js-yo-container'

# Full-width bottom rail: form paints left side, Filter pseudo continues to identical right edge.
assert root+' form.search-bar.js-search-bar{' in J
assert 'height:57px!important;' in J
assert 'border-top:1px solid #494d4d!important;' in J
assert 'border-bottom:1px solid #494d4d!important;' in J
sel=root+' .search-bar__open-filter-link-container.js-open-filter-link-container::before{'
assert sel in J
assert 'top:5px!important;bottom:5px!important;width:1px!important;background:#747a7c!important;' in J
sel2=root+' .search-bar__open-filter-link-container.js-open-filter-link-container::after{'
assert sel2 in J
assert "left:-1px!important;right:0!important;bottom:-1px!important;height:1px!important;background:#494d4d!important;" in J

# Circle stays fixed; only its text content is optically raised within the 20x20 badge.
qty=root+' .product-image__qty{'
assert qty in J
for tok in ('display:grid!important;','place-items:center!important;','width:20px!important;','height:20px!important;','padding:0 0 2px 0!important;','border-radius:50%!important;'):
    assert tok in J, tok

# Freeze FULL/VIEWPORT transport and walker to the last-known-good v7.495 implementation.
expected={
 'scripts/ui-probe.sh':'0fba3a4f81c9ef610e73c2e1a64a819be0dbc405c54f27d9f4bb8e93665d740a',
 'scripts/skeleton-probe.sh':'edb24377fffad68c853c88a66d794cf0853c2a4ed530e8fe6765acc52d62badb',
 'src/ADUniversalUIProbe7362.inc':'9042c7c1252b17fd419b414eae3be96f09a5596df969f7d8b3be29ea492c058b',
 'src/ADUniversalUIProbe7362.js.inc':'e64f2369db489ba0584c944db2f90eed2dcc933c6fc0a561e2a891449d2b285a',
 'src/ADUniversalUIProbe7362.frame.js.inc':'2c289dd38d6849130e9a1fa22fd216400964ab0785f8af7fa0aebf2b12cc1bb8',
 'src/ADUIProbeViewportSample7449.js.inc':'f78fcfcbba257e284eff71020c9d5cd7b2508c971a83dc4fcdb3636262c8eb8c',
 'src/ADPDPMainStream7451.js.inc':'f5a4903a04797f83c25346c9da2ff67003a83363cffcb9ab6fbdf2ee31635688',
 'src/ADUIProbeScroll7446.js.inc':'fbb2c8171e1c4a11065b7fdfcfa42abfdcf2161d2d8d97d21128f349065f7840',
}
for rel,h in expected.items():
    s=(R/rel).read_text().replace('7.497','7.CUR')
    assert hashlib.sha256(s.encode()).hexdigest()==h, rel

for bad in ('MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in J, bad
print('PASS: v7.497 extends the Orders rail, raises qty text inside the fixed circle, and freezes probe behavior to v7.495')

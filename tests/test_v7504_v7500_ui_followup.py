from pathlib import Path
import json, hashlib, re
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text()
J=''.join(json.loads(line) for line in (R/'src/ADNewMenus7482.js.inc').read_text().splitlines() if line.strip())
C=(R/'layout/DEBIAN/control').read_text()
V=(R/'scripts/validate.sh').read_text()
CMD=(R/'COMMANDS.md').read_text()
UI=(R/'scripts/ui-probe.sh').read_text()
SK=(R/'scripts/skeleton-probe.sh').read_text()
assert 'Version: 7.504~v7500-ui-followup' in C
assert '#define AD_VERSION "v7.504-v7500-ui-followup"' in T
assert 'VER=7.504' in UI
assert 'AD_PROBE_VERSION=7.504' in SK
assert 'tests/test_v7500_ci_repair.py' in V
assert not (R/'tests/test_v7500_ci_repair.py').exists()
assert 'AmazonDark-v7.504-v7500-ui-followup-source.zip' in CMD
assert 'AD_STRICT_VALIDATE=0 sh scripts/validate.sh' in CMD

# Successful v7.500 probe implementation is carried forward byte-for-byte except version strings.
expected={'scripts/ui-probe.sh':'0fba3a4f81c9ef610e73c2e1a64a819be0dbc405c54f27d9f4bb8e93665d740a','scripts/skeleton-probe.sh':'edb24377fffad68c853c88a66d794cf0853c2a4ed530e8fe6765acc52d62badb','src/ADUniversalUIProbe7362.inc':'9042c7c1252b17fd419b414eae3be96f09a5596df969f7d8b3be29ea492c058b','src/ADUniversalUIProbe7362.js.inc':'e64f2369db489ba0584c944db2f90eed2dcc933c6fc0a561e2a891449d2b285a','src/ADUniversalUIProbe7362.frame.js.inc':'2c289dd38d6849130e9a1fa22fd216400964ab0785f8af7fa0aebf2b12cc1bb8','src/ADUIProbeViewportSample7449.js.inc':'f78fcfcbba257e284eff71020c9d5cd7b2508c971a83dc4fcdb3636262c8eb8c','src/ADPDPMainStream7451.js.inc':'f5a4903a04797f83c25346c9da2ff67003a83363cffcb9ab6fbdf2ee31635688','src/ADUIProbeScroll7446.js.inc':'fbb2c8171e1c4a11065b7fdfcfa42abfdcf2161d2d8d97d21128f349065f7840'}
for rel,h in expected.items():
    ps=(R/rel).read_text().replace('7.504','7.CUR')
    assert hashlib.sha256(ps.encode()).hexdigest()==h, rel
W=(R/'.github/workflows/build.yml').read_text()
for tok in ('actions/checkout@v7','actions/setup-python@v7','actions/upload-artifact@v7','AD_STRICT_VALIDATE=1 sh scripts/validate.sh'):
    assert tok in W, tok

# Do not touch the historically locked shared-core function. This is the exact
# canonical hash contract used by the long-standing v7.369/v7.370 regressions.
def func(name):
    st=T.index(f'static NSString *{name}')
    b=T.index('{',st); d=0
    for i in range(b,len(T)):
        if T[i]=='{': d+=1
        elif T[i]=='}':
            d-=1
            if d==0: return T[st:i+1]
    raise AssertionError(name)
core=func('ADCoreWebJS7271').replace('] stringByAppendingString:ADNewMenusJS7482()',']').replace('=[[NSString','= [NSString').replace('()]];','()];').replace('= [NSString','=[NSString').replace('@"%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@"','@"%@%@%@%@"').replace(',ADProductShareThemeJS7403(),\n        ADProductShareTWBJS7403(),ADShareProbeSuppressJS7403(),ADProductScrollPolishJS7404(),\n        ADProductScrollVideoBorderJS7405(),ADPDPGridCarouselFix7454(),ADPDPCompletionJS7405(),ADPDPSafeFrameJS7432(),ADPDPCompletionTWBJS7405(),ADPDPUICompletionJS7439(),ADPDPMainResidualJS7440(),ADPDPProbeBackedFixesJS7458(),ADFrameOwnerTriggerJS7440(),ADAddressManagementJS7412()','')
assert hashlib.sha256(core.encode()).hexdigest() == '41ce925c9bad5362bf65204d4eb9778d016c2015b41b427704943df363b6d30c'

root='section.your-orders-mobile-content-container.aok-relative.js-yo-container'
# One Prime tame plane; no second image-container overlay. Text content is above it.
assert root+' [class*="_timely-reminders-information-tile_style_tileContainer"]::before{' in J
assert 'background:rgba(0,0,0,.58)!important;border-radius:inherit!important;z-index:1!important;' in J
assert root+' [class*="_timely-reminders-information-tile_style_imageContainer"]::after{' in J
assert 'content:none!important;display:none!important;background:none!important;box-shadow:none!important;' in J
assert root+' [class*="_timely-reminders-information-tile_style_tileContent"]{' in J
assert 'position:relative!important;z-index:2!important;' in J

# Returning from Filter can never paint Amazon's focus pseudo/ring around the text.
assert root+' .search-bar__open-filter-link::after{' in J
assert '.search-bar__open-filter-link.a-box-focus' in J
assert '.search-bar__open-filter-link .a-button-focus' in J
assert 'outline:0!important;outline-color:transparent!important;box-shadow:none!important;' in J

# v7.500 viewport-probe exact owner: 247/248/248 padding around thematic ad images -> OLED.
assert '#dp#dp [class*="_sp-mobile-thematic-bundle_thematicBundle-mobile_thumbnail-background__"]{' in J
assert 'background:#000!important;background-color:#000!important;border-color:#494d4d!important;' in J
assert '#dp#dp [class*="_sp-mobile-thematic-bundle_thematicBundle-mobile_image-display__"]{' in J
assert 'mix-blend-mode:normal!important;' in J

for bad in ('MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in J, bad
print('PASS: v7.504 starts from successful v7.500, keeps the locked core hash, normalizes Prime taming, clears Filter focus artifacts, and blacks the thematic image canvas')

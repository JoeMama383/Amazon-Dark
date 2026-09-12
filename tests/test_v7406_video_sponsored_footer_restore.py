from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
UI=(ROOT/'scripts/ui-probe.sh').read_text(); SK=(ROOT/'scripts/skeleton-probe.sh').read_text()
INC=(ROOT/'src/ADUniversalUIProbe7362.inc').read_text(); JS=(ROOT/'src/ADUniversalUIProbe7362.js.inc').read_text()
assert 'Version: 7.414~location-navigation-renderer-fix' in C
assert '#define AD_VERSION "v7.414-location-navigation-renderer-fix"' in S
block=S.split('static NSString *ADProductScrollVideoBorderJS7405(void){',1)[1].split('static NSString *ADPDPCompletionJS7405',1)[0]
assert '[class*=_c2Itd_shortProduct_]{border:1px solid #494d4d!important' in block
assert '[class*=_c2Itd_container_]{border:0!important' in block
assert '[class*=_c2Itd_singleAsin_]{border:0!important' in block
assert 'overflow:visible!important' in block
assert 'overflow:hidden!important' not in block
# Do not "fix" the footer by hiding/removing sponsored content or forcing a replacement layout.
for bad in ('display:none','visibility:hidden','opacity:0'):
    assert bad not in block
assert 'VER=7.414' in UI
assert 'AD_PROBE_VERSION=7.414' in SK and 'AD_PROBE_NAME=AmazonDark-v7.414' in SK
assert 'AMAZONDARK v7.414 UNIVERSAL' in INC and 'AmazonDark-v7.414-ui-viewport.arm' in INC
assert "version:'7.414'" in JS
print('PASS: v7.407 keeps one video+copy border while restoring the authored Sponsored footer and regenerates all probes')

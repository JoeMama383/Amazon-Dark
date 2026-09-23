from pathlib import Path
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text()
C=(R/'layout/DEBIAN/control').read_text()
UI=(R/'scripts/ui-probe.sh').read_text()
SK=(R/'scripts/skeleton-probe.sh').read_text()
assert 'Version: 7.460~home-hero-pill-owner-fix' in C
assert '#define AD_VERSION "v7.460-home-hero-pill-owner-fix"' in T
assert 'VER=7.460' in UI
assert 'AD_PROBE_VERSION=7.460' in SK and 'AD_PROBE_NAME=AmazonDark-v7.460' in SK
assert "ad7460-home-hero-pill" in T
assert "[class*='_single-video-card_style_sponsored-label-pill__']{background:rgba(0,0,0,.6)!important;background-color:rgba(0,0,0,.6)!important;}" in T
assert "#gwm-dashboard [class*='_single-video-card_style_sponsored-label-pill__']" not in T
print('PASS: v7.460 targets the captured single-video Sponsored pill directly with a fresh style identity')

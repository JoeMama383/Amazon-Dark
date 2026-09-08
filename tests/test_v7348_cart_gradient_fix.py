from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
t=(ROOT/'src/Tweak.xm').read_text()
c=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.364~universal-full-sweep-probes' in c
assert '#define AD_VERSION "v7.364-universal-full-sweep-probes"' in t
assert 'ADBlackenLoadingGradient7348' in t
assert '%hook AWLoadingIndicatorWidgets_BkgView' in t
assert '%hook AWLoadingIndicatorWidgets_Indicator' in t
assert '%hook AWLoadingIndicatorWidgets_HighlightView' in t
assert 'v.layer.contents=nil;' in t
assert 'AmazonDarkCartLoadingBar7345' in t
assert 'CART_STRIP_OWNER' in t
assert t.count('new MutationObserver(')==0
print('PASS: v7.348 exact native gradient/bar strip owners present; no production MutationObserver')

from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
M=(ROOT/'Makefile').read_text()
assert 'Version: 7.446~probe-responsiveness' in C
assert '#define AD_VERSION "v7.446-probe-responsiveness"' in S
assert '@interface IESSkeletonView : UIView @end' in S
assert '"AWLoadingIndicatorFullScreenModalBar","AWLoadingIndicatorWidgets_BkgView","IESSkeletonView"' in S
for fn in ['ADPDPTransitionSkeletonView7407','ADPDPTransitionSkeletonImage7407','ADPDPDarkSkeletonRaster7407','ADOwnPDPTransitionSkeletonImage7407','ADOwnPDPTransitionSkeletonView7407']:
    assert fn in S, fn
# Probe-proven native ownership only.
view=re.search(r'static BOOL ADPDPTransitionSkeletonView7407\(UIView \*v\)\{(.*?)\n\}',S,re.S).group(1)
assert 'IESSkeletonView' in view and 'AWLoadingIndicatorFullScreenModalBar' in view and 'AppCXWindow' in view
assert 'r.size.width>=sw*0.95' in view and 'r.size.height>=sh*0.72' in view
img=re.search(r'static BOOL ADPDPTransitionSkeletonImage7407\(UIImageView \*iv\)\{(.*?)\n\}',S,re.S).group(1)
assert 'im.size.width' in img and 'im.size.height' in img
assert 'im.scale>0.01?im.scale:1.0' in img
assert 'CGImageGetWidth(im.CGImage)' in img and 'CGImageGetHeight(im.CGImage)' in img
assert 'nw=pw?((CGFloat)pw/scale):iw' in img and 'nh=ph?((CGFloat)ph/scale):ih' in img
assert 'iw>=420.0&&iw<=520.0&&ih>=940.0&&ih<=1120.0' in img
assert 'nw>=420.0&&nw<=520.0&&nh>=940.0&&nh<=1120.0' in img
assert 'ar>0.38&&ar<0.50' in img
# White raster is inverted, then attenuated to Home-like dark gray skeleton bars.
raster=re.search(r'static UIImage \*ADPDPDarkSkeletonRaster7407\(UIImage \*im\)\{(.*?)\n\}',S,re.S).group(1)
assert 'kCGBlendModeDifference' in raster
assert '[UIColor whiteColor]' in raster
assert 'colorWithWhite:0 alpha:0.28' in raster
assert 'kCGBlendModeNormal' in raster
# Lifecycle ownership is event-driven and image writes are guarded/cached.
assert '%hook IESSkeletonView' in S
assert 'kADPDPSkeletonOriginal7407' in S and 'kADPDPSkeletonDark7407' in S
assert 'gADPDPSkeletonImageWrite7407' in S
assert 'ADOwnPDPTransitionSkeletonImage7407(self);' in S
# Explicit CoreGraphics linkage for the one-time blend transform.
assert 'CoreGraphics' in re.search(r'^AmazonDark_FRAMEWORKS.*$',M,re.M).group(0)
# No recurring machinery in the new helper block.
block=S[S.index('// v7.407 transition probe: Product Search -> PDP'):S.index('static BOOL ADAppLoadingSurface7130')]
for bad in ['MutationObserver(', 'setInterval(', 'requestAnimationFrame(', 'addEventListener(\'scroll\'', 'dispatch_after(']:
    assert bad not in block, bad
print('PASS: v7.407 scopes the Product Search -> PDP image-backed skeleton to the exact native owner and renders it OLED/dark without recurring runtime work')

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
S = (ROOT / "src/Tweak.xm").read_text()
C = (ROOT / "layout/DEBIAN/control").read_text()

assert "Version: 7.403~product-share-sheet-probe-control" in C
assert '#define AD_VERSION "v7.403-product-share-sheet-probe-control"' in S

# FULL r1: current price-to-pay family is neutral stock black and must be light.
price = "span.a-price[class*=_mobileDenseGridPriceToPay_]"
assert price in S
frag = S[S.index(price):S.index(price)+600]
assert "color:#e8e6e3!important" in frag
assert "-webkit-text-fill-color:#e8e6e3!important" in frag

# Keep authored red families separate; do not recolor the deal/savings selectors.
assert "[class*=_badgeMessage_]" in S
assert "[class*=deal]" in S
assert "[class*=saving]" in S

# v7.375 supersedes v7.374's layout-time reassertion: checkout is marked from the
# incoming modal before transition composition, and UINavigationBar has no layout owner.
assert "%hook AMSModalLayoutFullScreenViewController" in S
assert "ADOwnCheckoutModalPrepaint7375" in S
assert "%hook UINavigationBar" in S
nav = S[S.index("%hook UINavigationBar"):S.index("%hook CXIStoreModesBottomNavToolbar")]
assert "- (void)didMoveToWindow" in nav
assert "- (void)layoutSubviews" not in nav
assert "ADCheckoutNavAppearances7375" in nav

st = S.index("static NSString *ADCheckoutFloorJS7369")
en = S.index("static NSString *ADPrivacyModeJS7117", st)
isolated = S[st:en]
for bad in ("MutationObserver(", "setInterval(", "requestAnimationFrame("):
    assert bad not in isolated

print("PASS: v7.375 preserves BYG price and moves checkout first-paint ownership before layout")

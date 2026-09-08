from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
S = (ROOT / "src/Tweak.xm").read_text()
C = (ROOT / "layout/DEBIAN/control").read_text()

assert "Version: 7.374~byg-price-checkout-first-paint" in C
assert '#define AD_VERSION "v7.374-byg-price-checkout-first-paint"' in S

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

# FULL r2: first-paint native ownership is now on UINavigationBar layout/didMove,
# not a timer or recurring scanner.
assert "%hook UINavigationBar" in S
nav = S[S.index("%hook UINavigationBar"):S.index("%hook CXIStoreModesBottomNavToolbar")]
assert "- (void)didMoveToWindow" in nav
assert "- (void)layoutSubviews" in nav
assert "ADOwnCheckoutNav7369((_UIBarBackground *)v);" in nav

st = S.index("static NSString *ADCheckoutFloorJS7369")
en = S.index("static NSString *ADPrivacyModeJS7117", st)
isolated = S[st:en]
for bad in ("MutationObserver(", "setInterval(", "requestAnimationFrame("):
    assert bad not in isolated

print("PASS: v7.374 BYG price + checkout first-paint ownership")

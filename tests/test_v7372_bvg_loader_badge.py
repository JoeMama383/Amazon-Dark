from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()

assert 'Version: 7.391~ui-completion-audit-fix' in C
assert '#define AD_VERSION "v7.391-ui-completion-audit-fix"' in S

loader = "#checkoutDisplayPage .checkout-byg-mobile-container li.a-carousel-card.a-carousel-card-empty>.a-loading-static"
inner = "#checkoutDisplayPage .checkout-byg-mobile-container li.a-carousel-card.a-carousel-card-empty>.a-loading-static>.a-loading-static-inner"
badge = "#checkoutDisplayPage .checkout-byg-mobile-container [class*=_badgeMessage_]"

assert loader in S
assert "background:#303335!important" in S[S.index(loader):S.index(loader)+700]
assert "border:1px solid #494d4d!important" in S[S.index(loader):S.index(loader)+700]
assert inner in S
frag=S[S.index(inner):S.index(inner)+600]
assert "filter:brightness(0) invert(1) brightness(.62)!important" in frag
assert "opacity:.72!important" in frag

assert badge in S
bfrag=S[S.index(badge):S.index(badge)+400]
assert "background:transparent!important" in bfrag
assert "background-color:transparent!important" not in bfrag  # covered by the transparent shorthand

# The checkout patch remains isolated and declarative.
st=S.index("static NSString *ADCheckoutFloorJS7369")
en=S.index("static NSString *ADPrivacyModeJS7117",st)
frag=S[st:en]
for bad in ("MutationObserver(", "setInterval(", "requestAnimationFrame("):
    assert bad not in frag

print("PASS: v7.372 BYG loader and countdown badge parity")

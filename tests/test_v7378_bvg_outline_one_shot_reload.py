from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
SB=(ROOT/'src/AmazonDarkSB.xm').read_text()

assert 'Version: 7.378~byg-outline-one-shot-reload' in C
assert '#define AD_VERSION "v7.378-byg-outline-one-shot-reload"' in S

# New FULL capture: collapsed BYG add circle is correct except for Amazon's retained focus outline.
sel="#checkoutDisplayPage .checkout-byg-mobile-container [class*=_denseGridAxSpotAtcButton_] button[name='submit.addToCart']"
pos=S.index(sel)
css=S[pos:S.index('}#checkoutDisplayPage .checkout-byg-mobile-container [class*=_denseGridAxSpotAtcButton_] .a-icon-small-add',pos)+1]
for token in [
    'background:#303335!important',
    'border:1px solid #747a7c!important',
    'outline:none!important',
    'outline-color:transparent!important',
    '-webkit-tap-highlight-color:transparent!important',
    "button[name='submit.addToCart']:is(:focus,:focus-visible,:active)",
]: assert token in css, token
# The real circular edge is preserved; do not solve the artifact by deleting the border.
assert 'border:0!important' not in css

# v7.377's synchronous scroll/resize nudge was disproven by the new post-sweep 24/23 capture.
hyd=S[S.index('static NSString *ADCheckoutBYGHydrateJS7378'):S.index('static NSString *ADPrivacyModeJS7117')]
for token in [
    "var K='ad7-byg-atc-retry-7378'",
    'cards.length<6',
    'sparse!==1',
    'healthy!==cards.length-1',
    "sessionStorage.getItem(K)==='1'",
    "sessionStorage.setItem(K,'1')",
    'location.reload()',
    'sessionStorage.removeItem(K)',
]: assert token in hyd, token
for disproven in ["vp.scrollLeft", "dispatchEvent(new Event('scroll'", "dispatchEvent(new Event('resize'"]:
    assert disproven not in hyd, disproven
for bad in ['MutationObserver','setInterval','setTimeout','requestAnimationFrame','createElement(\'button\')','createElement("button")']:
    assert bad not in hyd, bad

# Launch/switcher production hook surface stays exactly provenance-based; only diagnostic version text changes.
for bad in ['%hook SBDeviceApplicationSceneViewPlaceholderContentViewProvider','task-switcher','WarmSnapshotCover','switcher-release']:
    assert bad not in SB+S, bad
assert '%hook XBApplicationSnapshot' in SB
assert 'kind==ADKindScene7337)return 0;' in SB

print('PASS: v7.378 removes the BYG focus-outline corners and uses one guarded real-renderer reload without recurring work')

from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.468~pdp-ad-book-ci-reconcile' in C
assert '#define AD_VERSION "v7.468-pdp-ad-book-ci-reconcile"' in S
assert len(S.encode()) < 856000
marker='// One immutable document-start program per strength replaces four separately\n// allocated/compiled WKUserScripts while preserving their proven execution order.'
a=S.index('static NSString *ADAddressManagementJS7412(void){')
m=S.index(marker,a)
g=S.index('static long gADCoreWebJSStrength7271=-1;',a)
assert a < m < g
web=S[a:m]
assert '#ya-myab-address-add-link' in web and '[id^=ya-myab-display-address-block-]' in web
# This boundary is consumed by several frozen historical regressions; keep it stable.
for bad in ('new MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in web,bad
# v7.464 visual ownership remains inherited.
for tok in ['kADPDPChildUS7464','AmazonDarkPDP7464','#productInfoTabExpanderHeader0>.a-expander-content-fade','#ad>div>div>div:has(#offsite-buy-box)']:
    assert tok in S,tok
for h in ['## FULL — v7.468','## VIEWPORT — v7.468','## TRANSITION — v7.468']:
    assert h in CMD,h
print('PASS: v7.468 restores the historical immutable-core sentinel while preserving v7.464 PDP ownership')

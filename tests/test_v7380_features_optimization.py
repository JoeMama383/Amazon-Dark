from pathlib import Path
import re, subprocess, tempfile
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
A=(ROOT/'src/ADSponsored.m').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
P=(ROOT/'prefs/Resources/Root.plist').read_text()
W=(ROOT/'.github/workflows/build.yml').read_text()
V=(ROOT/'scripts/validate.sh').read_text()
SB=(ROOT/'src/AmazonDarkSB.xm').read_text()

assert 'Version: 7.385~sponsored-c-linkage-fix' in C
assert '#define AD_VERSION "v7.385-sponsored-c-linkage-fix"' in S
for key in ['hideSponsored','priceHistory']:
    assert key in S and f'<string>{key}</string>' in P
assert '<string>Hide Sponsored Content</string>' in P
assert '<string>Price History</string>' in P
assert 'ADKillerSponsoredJS7384' in S and 'ADKillerSponsoredJS7384' in A and 'ADPriceHistoryJS7380' in S
assert 'MutationObserver' not in A
for bad in ['setInterval(', 'setTimeout(', 'requestAnimationFrame(', 'scroll-listener-sentinel']:
    assert bad not in A
for token in ['.s-result-item.AdHolder','[data-ad-feedback-label-id]','sp-cart-mobile-carousel-cards','SponsoredProducts']:
    assert token in A
for token in ['graph.keepa.com/pricehistory.png','charts.camelcamelcamel.com','range=90','loading=\'lazy\'','encodeURIComponent(asin)']:
    assert token in S
assert 'ADActiveCheckoutModal7380' in S
assert 'BOOL duplicate=(active&&active!=viewControllerToPresent);' in S
# App switcher remains non-interference: passive XIB probe may observe only, never replace.
assert 'ADObservePlaceholder7379(application,original);' in SB
assert 'return original;' in SB
assert 'AmazonDarkWarmSnapshotCover' not in S
assert 'kADWarmSnapshotCover' not in S
# Packaging permission is normalized and enforced by CI/validator.
assert 'chmod 755 layout/DEBIAN/postinst' in W
assert 'postinst must be executable' in V
# No duplicate static function definitions and no obviously dead static function definitions.
funcs=re.findall(r'(?m)^static\s+(?:inline\s+)?(?:[\w<>\s\*]+?)\s+([A-Za-z_]\w*)\s*\([^;\n]*\)\s*\{',S)
assert len(funcs)==len(set(funcs)), 'duplicate static function definition'
for name in funcs:
    assert len(re.findall(r'\b'+re.escape(name)+r'\b',S))>=2, f'obviously dead static function: {name}'
# Hook classes should be unique; grouped hooks are explicitly allowed via %group but current source has none duplicated.
hooks=re.findall(r'(?m)^%hook\s+([A-Za-z_]\w*)',S)
assert len(hooks)==len(set(hooks)), 'duplicate %hook class block'
print('PASS: v7.385 features, structural checkout dedupe, switcher non-interference, packaging guard, dead/duplicate static audit')

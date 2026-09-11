from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
A=(ROOT/'src/ADSponsored.m').read_text()
H=(ROOT/'src/ADSponsored.h').read_text()
M=(ROOT/'Makefile').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.408~permission-location-switcher-hardening' in C
assert '#define AD_VERSION "v7.408-permission-location-switcher-hardening"' in S
assert 'AmazonDark_FILES      = src/Tweak.xm src/ADSponsored.m' in M
assert '#import "ADSponsored.h"' in S
assert 'extern "C" {' in H
assert 'NSString *ADKillerSponsoredJS7384(void);' in H
assert 'static NSString *ADKillerSponsoredJS7382(void)' not in S
assert '#import "ADSponsored.h"' in A
assert 'NSString *ADKillerSponsoredJS7384(void)' in A
assert "ad7384-killer" in A
assert A.count('{display:none!important') == 33  # all 86 selectors checked separately in v7.388 semantic test
assert ':has(:has(' not in A
assert 'ADSharedUserScript7387(1,ADKillerSponsoredJS7384,NO,NO)' in S and 'injectionTime:WKUserScriptInjectionTimeAtDocumentStart' in S
print('PASS: sponsored payload is outside Logos, C-linkage-safe, and document-start injected')

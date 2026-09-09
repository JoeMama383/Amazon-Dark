from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
A=(ROOT/'src/ADSponsored.m').read_text()
M=(ROOT/'Makefile').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.384~sponsored-logos-build-fix' in C
assert '#define AD_VERSION "v7.384-sponsored-logos-build-fix"' in S
assert 'AmazonDark_FILES      = src/Tweak.xm src/ADSponsored.m' in M
assert 'extern NSString *ADKillerSponsoredJS7384(void);' in S
assert 'static NSString *ADKillerSponsoredJS7382(void)' not in S
assert 'NSString *ADKillerSponsoredJS7384(void)' in A
assert "ad7384-killer" in A
assert A.count('{display:none!important') >= 75
assert ':has(:has(' not in A
assert 'ADKillerSponsoredJS7384() injectionTime:WKUserScriptInjectionTimeAtDocumentStart' in S
print('PASS: sponsored payload is outside Logos and remains document-start injected')

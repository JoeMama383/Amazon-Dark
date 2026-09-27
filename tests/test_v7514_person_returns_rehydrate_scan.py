from pathlib import Path
import hashlib
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text(); P=(R/'src/ADPersonReturns7514.inc').read_text(); U=(R/'src/ADUniversalUIProbe7362.inc').read_text(); C=(R/'layout/DEBIAN/control').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.514~person-returns-rehydrate-scan' in C
assert '#define AD_VERSION "v7.514-person-returns-rehydrate-scan"' in T
assert '#include "ADPersonReturns7514.inc"' in T
assert 'yr-titlettl' in T and 'ADPersonPrimeReturns7514(root)' in T
assert 'ADPersonReturnsUnder7514(v)' in T
assert 'AmazonDarkPersonReturnsOutline7514' in P
assert 'CGRectInset(v.bounds,0.75,0.75)' in P
assert 'w>=250.0&&w<=335.0&&h>=52.0&&h<=105.0' in P
assert 'ADPersonOwnText7206(v)' in P and 'seen++<48' in P
assert P.count('MutationObserver(')==0 and P.count('setInterval(')==0 and P.count('requestAnimationFrame(')==0
needle='[cn rangeOfString:@"RCTCustomScroll" options:NSCaseInsensitiveSearch].location!=NSNotFound'
assert U.count(needle)==2,U.count(needle)
assert 'AmazonDark-v7.514-person-returns-rehydrate-scan-source.zip' in CMD
assert len(T.encode())<856000,len(T.encode())
print('PASS: v7.514 owns Returns rehydration at the exact section/card family and ranks RCTCustomScrollView for universal FULL scanning')
